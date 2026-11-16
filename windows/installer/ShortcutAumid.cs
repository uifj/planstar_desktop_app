using System;
using System.Runtime.InteropServices;

namespace Planstar.Installer
{
    /// <summary>
    /// Writes / reads System.AppUserModel.ID on an existing .lnk file.
    /// Windows toast notifications for Win32 apps require a Start menu shortcut
    /// whose AppUserModelID matches the value passed to
    /// SetCurrentProcessExplicitAppUserModelID by the application.
    /// </summary>
    public static class ShortcutAumid
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct PROPERTYKEY
        {
            public Guid fmtid;
            public uint pid;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROPVARIANT
        {
            public ushort vt;
            public ushort r1;
            public ushort r2;
            public ushort r3;
            public IntPtr pointer;
        }

        [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IPropertyStore
        {
            void GetCount(out uint count);
            void GetAt(uint index, out PROPERTYKEY key);
            void GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
            void SetValue(ref PROPERTYKEY key, ref PROPVARIANT value);
            void Commit();
        }

        [ComImport, Guid("0000010b-0000-0000-C000-000000000046"),
         InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IPersistFile
        {
            void GetClassID(out Guid clsid);
            void IsDirty();
            void Load([MarshalAs(UnmanagedType.LPWStr)] string fileName, uint mode);
            void Save([MarshalAs(UnmanagedType.LPWStr)] string fileName,
                      [MarshalAs(UnmanagedType.Bool)] bool remember);
            void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string fileName);
            void GetCurFile(out IntPtr fileName);
        }

        // CLSID_ShellLink / IID_IUnknown / CLSCTX_INPROC_SERVER
        private static readonly Guid ClsidShellLink =
            new Guid("00021401-0000-0000-C000-000000000046");
        private static readonly Guid IidUnknown =
            new Guid("00000000-0000-0000-C000-000000000046");
        private static readonly Guid IidPropertyStore =
            new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        private static readonly Guid PkeyAppUserModelIdFormat =
            new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");

        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(ref Guid rclsid, IntPtr outer,
            uint context, ref Guid riid, out IntPtr instance);

        private static IPersistFile Open(string path, out IntPtr unknown)
        {
            Guid clsid = ClsidShellLink;
            Guid iid = IidUnknown;
            int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 1,
                                      ref iid, out unknown);
            if (hr != 0) throw new COMException("CoCreateInstance(ShellLink)", hr);
            IPersistFile file =
                (IPersistFile)Marshal.GetTypedObjectForIUnknown(unknown, typeof(IPersistFile));
            file.Load(path, 2 /* STGM_READWRITE */);
            return file;
        }

        private static IPropertyStore Store(IntPtr unknown)
        {
            IntPtr ptr = IntPtr.Zero;
            Guid iid = IidPropertyStore;
            int hr = Marshal.QueryInterface(unknown, ref iid, out ptr);
            if (hr != 0) throw new COMException("IPropertyStore unavailable", hr);
            try
            {
                return (IPropertyStore)Marshal.GetTypedObjectForIUnknown(ptr, typeof(IPropertyStore));
            }
            finally
            {
                Marshal.Release(ptr);
            }
        }

        public static void SetOnFile(string path, string appUserModelId)
        {
            IntPtr unknown = IntPtr.Zero;
            IntPtr strPtr = IntPtr.Zero;
            try
            {
                IPersistFile file = Open(path, out unknown);
                PROPERTYKEY key = new PROPERTYKEY { fmtid = PkeyAppUserModelIdFormat, pid = 5 };
                strPtr = Marshal.StringToHGlobalUni(appUserModelId);
                PROPVARIANT value = new PROPVARIANT { vt = 31 /* VT_LPWSTR */, pointer = strPtr };
                IPropertyStore store = Store(unknown);
                store.SetValue(ref key, ref value);
                store.Commit();
                file.Save(path, true);
            }
            finally
            {
                if (strPtr != IntPtr.Zero) Marshal.FreeHGlobal(strPtr);
                if (unknown != IntPtr.Zero) Marshal.Release(unknown);
            }
        }
    }
}
