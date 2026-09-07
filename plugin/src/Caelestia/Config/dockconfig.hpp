#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

class DockConfig : public settings::ObjectNode {
    CONFIG_NODE(DockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, showBackground, true)
    CONFIG_PROPERTY(int, iconSize, 28)
    // Monitor: this screen's active workspace only. SharedWorkspace: every
    // screen's active workspace, combined (same set on every dock) - for
    // setups where matching workspace numbers across monitors are treated as
    // one virtual desktop. Global: every running app everywhere.
    CONFIG_ENUM_PROPERTY(DockScope, scope, DockScope::Monitor)
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, pinnedApps, {})
};

} // namespace caelestia::config
