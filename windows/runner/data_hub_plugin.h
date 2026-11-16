#ifndef RUNNER_DATA_HUB_PLUGIN_H_
#define RUNNER_DATA_HUB_PLUGIN_H_

#include <flutter/binary_messenger.h>

// Registers the process-wide data hub channels for one Flutter engine.
// Must be called once per engine (main window + every desktop_multi_window
// child engine), because BinaryMessenger is engine-private.
void RegisterDataHubPlugin(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_DATA_HUB_PLUGIN_H_
