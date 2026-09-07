#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class DockConfig : public settings::ObjectNode {
    CONFIG_NODE(DockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, showBackground, true)
    CONFIG_PROPERTY(int, iconSize, 28)
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, pinnedApps, {})
};

} // namespace caelestia::config
