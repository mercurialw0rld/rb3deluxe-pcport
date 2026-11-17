// rockband3deluxe - ReXGlue Recompiled Project

#include "generated/default/rockband3deluxe_init.h"

#include "rockband3deluxe_app.h"
REXCVAR_DEFINE_BOOL(achievement_popups, false, "UI", "Show optional achievement popups (continuous overlay rendering)")
    .lifecycle(rex::cvar::Lifecycle::kInitOnly);

REX_DEFINE_APP(rockband3deluxe, RockBand3DeluxeApp::Create)
