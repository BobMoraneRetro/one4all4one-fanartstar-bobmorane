"RFE Retrofist Nostalgia" view (Salon): one background per system
=================================================================

In this folder:
  LISEZMOI.txt (français), README.txt (English), LEEME.txt (español), LEIAME.txt (português)
  README_backgrounds.txt : list and description of the supplied backgrounds (LISEZMOI_decors.txt, LEEME_fondos.txt, LEIAME_fundos.txt)
  exemple_complet.xml    : settings file with ALL options, to copy under the system's name

File location:
  default         : <theme>/_gamemedia/_salon/  (the parent folder of this one)
  external folder : themes/_bobmedia/_gamemedia/_salon/  (next to the themes), if the option
                    "Location of RFE Retrofist Nostalgia view backgrounds" = External folder
  Paths quoted below (_viewgame/..., collections.info) start from the theme's root folder.

For each system:
  <system>.png   : 1920x1080 background, TV screen TRANSPARENT (the video plays underneath)
  <system>.xml   : system settings (optional)
  _default.png   : default background for 4:3 systems (if the system has none)
  _default.xml   : settings of _default.png
  _default16.png : default background for 16:9 systems: ps3, ps4, xbox360,
                   wiiu, switch, psvita, windows, steam
                   (list in _viewgame/presetsalon.xml, variable salon_defaut)
  _default16.xml : settings of _default16.png
  Default backgrounds per system type (arcade, computers, portable...): see README_backgrounds.txt.
  Do not put salon_disque_tourne in these default files: they are read after the view and would override the rotation of CD systems.

Order in which settings are read (each file replaces what came before, only for the lines it contains):
  1. view values (_viewgame/presetsalon.xml, = wii settings)
  2. _default.xml (4:3 systems) or _default16.xml (16:9 systems)
  3. <system>.xml
A file may contain a single line (e.g. wiiu.xml: disc rotation only).

Settings of <system>.xml (coordinates as a fraction of the screen, 0 0 = top left, 1 1 = bottom right):
  salon_video_pos      centre of the TV screen                       e.g. 0.5 0.2625
  salon_video_taille   width height of the TV screen                 e.g. 0.3906 0.388
  salon_video_etiree   false = the video keeps its proportions (maxSize, black bars possible)
                       true  = the video is stretched to fill the whole TV screen (size)
  salon_capture_pos    centre of the game screenshot                 e.g. 0.5 0.2625
  salon_capture_taille width height of the screenshot                e.g. 0.3906 0.388
                       (screenshot shown when the game has no video, and before the video with the option
                        "Game video: Screenshot then video"; same stretched/proportions rule as the video)
                       Put both lines in every <system>.xml: otherwise those of _default.xml apply.
  Disc (coordinates INSIDE the carousel box cell: 0.5 = centre of the box):
  salon_disque_depart  x of the disc hidden behind the box           e.g. 0.5
  salon_disque_x       x of the disc once out (right edge 0.69)      e.g. 0.69
  salon_disque_y       height of the disc centre                     e.g. 0.65
  salon_disque_taille  maximum disc size (= box width)               e.g. 0.38 0.675
  salon_disque_tourne  true = the disc spins, false = the media slides out without spinning
                       (default true for CD/DVD systems, false for cartridges)
  salon_support_mixte  true = system mixing discs and cards/cartridges: the shape of the image decides
                       (round image, 4 transparent corners = spinning disc; otherwise fixed media).
                       Default true for wiiu, xbox360, windows and collections (es_systems THEME names).
                       Takes priority over salon_disque_tourne. Uses a detection shader: keep it for systems
                       that need it; do not put it in _default.xml unless you want it for all.
  salon_couleur        colour multiplied over the video and screenshot (FFFFFFFF = none, default)
  salon_saturation     1 = normal (default), 0 = black and white; with salon_couleur 8BAC0F = green Game Boy screen
  salon_calque         image laid over the screen (glass, LCD grid), empty = none (default)
                       e.g. gb.xml: <salon_calque>${path_salon}/gb_ecran.png</salon_calque>
  salon_ecran2         true = 2nd screen (2 consoles linked by cable): same video, screenshot, colour and overlay as the 1st.
                       false by default. With: salon_video2_pos (centre of the 2nd screen) and salon_video2_taille
                       (width height). The 1st screen keeps salon_video_pos/taille. E.g. gbc2players.xml.
  Screen perspective (TV seen from the side, tilted screen, photo frame set at an angle):
  salon_perspective    0 = none (default); 1 = by angles; 2 = by the 4 corners of the screen
    1, by angles (same principle as the Boxart view): video and screenshot keep their area
       (salon_video_pos/taille, salon_capture_pos/taille, always stretched) and are tilted:
       salon_persp_angle_x    rotation around the vertical axis, in degrees   e.g. 20 (try -20 for the other side)
       salon_persp_angle_y    rotation around the horizontal axis, in degrees e.g. 0
       salon_persp_profondeur 1 = default; smaller = bigger image
       Adjusted by trial and error. salon_saturation is not applied in this mode (salon_couleur is).
    2, by the 4 corners: video, screenshot, black background and overlay fit the background's screen exactly.
       In the background PNG, note the 4 corners of the screen (in pixels, x y, as in "Measuring the screen"):
       salon_coin_hg   top-left corner                 e.g. 702 205
       salon_coin_hd   top-right corner                e.g. 1254 190
       salon_coin_bd   bottom-right corner             e.g. 1262 571
       salon_coin_bg   bottom-left corner              e.g. 696 560
       salon_coins_proportions  0 = the image fills the screen (default), 1 = proportions kept (black bars)
       salon_video_pos/taille and salon_capture_pos/taille are not used in this mode.
    The 2nd screen (salon_ecran2) never has perspective.

Measuring the screen: centre x = (left + right) / 2 / 1920, y = (top + bottom) / 2 / 1080,
width = (right - left) / 1920, height = (bottom - top) / 1080.
Copy wii.xml (or exemple_complet.xml) under the system's name and change the values.

Example: PS1 background (psx.png, 1920x1080)
  1. Open the PNG in an image editor and note the edges of the TV screen (transparent area):
       left = 711 px   right = 1266 px   top = 198 px   bottom = 565 px
  2. Screen centre (salon_video_pos):
       x = (711 + 1266) / 2 / 1920 = 988.5 / 1920 = 0.5148
       y = (198 + 565)  / 2 / 1080 = 381.5 / 1080 = 0.3532
  3. Screen size (salon_video_taille):
       width  = (1266 - 711) / 1920 = 555 / 1920 = 0.2891  (rounded up a little: 0.2896)
       height = (565 - 198)  / 1080 = 367 / 1080 = 0.3398  (rounded up a little: 0.3407)
  4. In psx.xml (dot as decimal separator, x then y separated by a space):
       <salon_video_pos>0.5148 0.3532</salon_video_pos>
       <salon_video_taille>0.2896 0.3407</salon_video_taille>
  Tip: round the size slightly up to avoid a thin line between the video and the TV frame.
  The video keeps its proportions: if the background's screen has another shape, a black background fills the sides.

Media size (disc / cartridge) per system: salon_disque_taille and salon_disque_x are CALCULATED
(one value per "Game box to display" mode: 2D box = thumb, 3D box = boxart) at the real scale of the displayed box,
capped at 85 % of the box. Also used by the Boxart view.

Examples of <system>.xml for each situation
  Every file has the same wrapper; only the lines between <variables> and </variables> change:
    <?xml version="1.0" encoding="UTF-8"?>
    <theme>
    	<formatVersion>7</formatVersion>
    	<variables>
    		... lines below ...
    	</variables>
    </theme>
  Only put the lines you need: a missing line keeps the value of the view or of the default file.
  exemple_complet.xml contains every possible line.

  1. Cartridge console, 4:3 TV, video stretched to fill the screen (e.g. snes.xml):
       <salon_video_pos>0.51 0.31</salon_video_pos>
       <salon_video_taille>0.3 0.33</salon_video_taille>
       <salon_capture_pos>0.51 0.31</salon_capture_pos>
       <salon_capture_taille>0.3 0.33</salon_capture_taille>
       <salon_video_etiree>true</salon_video_etiree>
     The cartridge slides out of the box without spinning (cartridge default); its size is set like the disc (examples 3 and 4).

  2. 16:9 TV with 4:3 games: proportions kept, black bars on the sides (e.g. windows.xml):
       same 4 position/size lines as example 1, then
       <salon_video_etiree>false</salon_video_etiree>

  3. Disc console, spinning disc, disc size calculated for each "Game box" mode (e.g. psx.xml):
       <salon_video_pos>0.5148 0.3532</salon_video_pos>
       <salon_video_taille>0.2922 0.3449</salon_video_taille>
       <salon_capture_pos>0.5148 0.3532</salon_capture_pos>
       <salon_capture_taille>0.2922 0.3449</salon_capture_taille>
       <salon_disque_depart>0.5</salon_disque_depart>
       <salon_disque_y>0.65</salon_disque_y>
       <salon_disque_taille ifSubset="boxorthumb:thumb">0.2900 0.5156</salon_disque_taille>
       <salon_disque_taille ifSubset="boxorthumb:boxart">0.2447 0.4350</salon_disque_taille>
       <salon_disque_x ifSubset="boxorthumb:thumb">0.6900</salon_disque_x>
       <salon_disque_x ifSubset="boxorthumb:boxart">0.6772</salon_disque_x>
     thumb = 2D box, boxart = 3D box (keep the boxart lines last: default choice). Rotation is already on for CD/DVD systems.

  4. Same disc size whatever the "Game box" mode (set by hand, without ifSubset):
       <salon_disque_x>0.69</salon_disque_x>
       <salon_disque_y>0.65</salon_disque_y>
       <salon_disque_taille>0.36 0.64</salon_disque_taille>
     For a smaller disc, lower both values of salon_disque_taille in the same proportion.

  5. Change only the rotation (one-line file):
       disc slides out without spinning : <salon_disque_tourne>false</salon_disque_tourne>
       spinning media (e.g. CD)         : <salon_disque_tourne>true</salon_disque_tourne>

  6. System or collection mixing discs and cartridges (e.g. burnout.xml, Dragon Ball Z.xml):
       screen position/size lines, then
       <salon_video_etiree>false</salon_video_etiree>
       <salon_support_mixte>true</salon_support_mixte>
     Round image (4 transparent corners) = spinning disc; any other shape = fixed media.
     Takes priority over salon_disque_tourne.

  7. PSP (UMD): only the disc visible in the shell spins, the shell and the "UMD" centre stay still.
     Add only if the UMD images used are not centred like the original ones
     (default values below, as a fraction of the media image):
       <salon_umd_cx>0.5</salon_umd_cx>                  horizontal centre of the disc
       <salon_umd_cy>0.49</salon_umd_cy>                 vertical centre of the disc
       <salon_umd_rayon>0.45</salon_umd_rayon>           radius of the spinning part
       <salon_umd_rayon_centre>0.23</salon_umd_rayon_centre>  radius of the fixed centre
     Rotation can be switched off with the option "UMD rotation (PSP)".

  8. Monochrome LCD screen (e.g. gb.xml): stretched video, green tint, pixel overlay:
       screen position/size lines, then
       <salon_video_etiree>true</salon_video_etiree>
       <salon_couleur>A9840C</salon_couleur>
       <salon_saturation>0</salon_saturation>
       <salon_calque>${path_salon}/gb_ecran.png</salon_calque>
     The overlay is a PNG placed in the _salon folder; ${path_salon} points to that folder (or to _bobmedia, depending on the option).
     Black and white video only: <salon_saturation>0</salon_saturation> without salon_couleur.

  9. Two screens (2 linked consoles, e.g. gbc2players.xml):
       <salon_video_pos>0.3526 0.3194</salon_video_pos>      1st screen (the screenshot is set as for a single screen)
       <salon_video_taille>0.1109 0.1843</salon_video_taille>
       <salon_capture_pos>0.3526 0.3194</salon_capture_pos>
       <salon_capture_taille>0.1109 0.1843</salon_capture_taille>
       <salon_ecran2>true</salon_ecran2>
       <salon_video2_pos>0.6534 0.3194</salon_video2_pos>    2nd screen
       <salon_video2_taille>0.1104 0.1843</salon_video2_taille>
       <salon_video_etiree>true</salon_video_etiree>

  10. Vertical screen or page (e.g. library.xml: magazines, manuals): the area is taller than wide,
      the image is stretched to fill the page:
       <salon_video_pos>0.499 0.5366</salon_video_pos>
       <salon_video_taille>0.1896 0.4361</salon_video_taille>
       <salon_capture_pos>0.499 0.5366</salon_capture_pos>
       <salon_capture_taille>0.1896 0.4361</salon_capture_taille>
       <salon_video_etiree>true</salon_video_etiree>

  11. Screenshot placed somewhere else than the video (e.g. screenshot in a photo frame of the background, video on the TV):
       salon_capture_pos / salon_capture_taille with the photo frame measurements,
       salon_video_pos / salon_video_taille with those of the TV.

  12. Collection: same content as a <system>.xml.
       automatic collection : auto-<name>.xml (e.g. auto-lightgun.xml)
       custom collection    : exact name of the collection, spaces included (e.g. Dragon Ball Z.xml)
     A collection often mixes media: set salon_support_mixte to true (example 6).

  13. Default files (_default.xml, _default16.xml, arcade.xml, portable.xml...): put the 4 screen
      position/size lines and salon_video_etiree. Do not put salon_disque_tourne
      or salon_support_mixte in them: they would replace each system's own value.

  14. TV seen from the side: the background's screen is a quadrilateral (perspective by the 4 corners):
       <salon_perspective>2</salon_perspective>
       <salon_coin_hg>702 205</salon_coin_hg>
       <salon_coin_hd>1254 190</salon_coin_hd>
       <salon_coin_bd>1262 571</salon_coin_bd>
       <salon_coin_bg>696 560</salon_coin_bg>
     Values in pixels of the background PNG (x y). To keep the video proportions: <salon_coins_proportions>1</salon_coins_proportions>.
     Variant by angles, adjusted by trial and error:
       <salon_perspective>1</salon_perspective>
       <salon_persp_angle_x>20</salon_persp_angle_x>
       <salon_persp_angle_y>0</salon_persp_angle_y>
       <salon_persp_profondeur>1</salon_persp_profondeur>

Automatic collections: theme name auto-<name> (auto-favorites, auto-lastplayed, auto-allgames, auto-lightgun, auto-wheel...)
Custom collections: the file has the exact name of the collection (spaces included), list of recognised names: collections.info (theme root)
