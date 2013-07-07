#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

public Plugin:myinfo = 
{
    name = "War3Source - Addon - L4D - Painter",
    author = "Glider",
    description = "Enables the coloring of special infected.",
    version = "1.0",
};

public OnMapStart()
{
    AddFileToDownloadsTable("addons\\specialallowcoloring.vpk");
}
