extends RefCounted

# The build number shown on the HUD (Dave: it goes up with every build). Provisional on a thread branch; the Technical Director
# renumbers at merge and appends tech/BUILD_LOG.md. Lives alone in this file so threads stop conflicting on terrain_client.gd.
const NUMBER := 786
