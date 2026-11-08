# One4All4One - vue RFE Retrofist Nostalgia : cree ou modifie le fichier de reglages <systeme>.xml d'un decor.
# Mesure la zone transparente du PNG et donne acces a tous les reglages de la vue.
# Les lignes que l'outil ne connait pas ne sont jamais touchees ; l'ancienne version est sauvegardee.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('CalageSalon.Mesure' -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
namespace CalageSalon {
  public class Zone {
    public int X0, Y0, X1, Y1, Aire;
    public double Remplissage, Ecart, Residu;
    public double[] CX = new double[4];   // haut-gauche, haut-droit, bas-droit, bas-gauche
    public double[] CY = new double[4];
  }
  public class Resultat {
    public int Largeur, Hauteur, NbBord, NbPetites;
    public Zone[] Zones;
  }
  public static class Mesure {
    public static Resultat Analyser(string chemin, int seuil, double aireMini) {
      int w, h; byte[] a;
      using (Bitmap bmp = new Bitmap(chemin)) {
        w = bmp.Width; h = bmp.Height; a = new byte[w * h];
        BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] ligne = new byte[w * 4];
        for (int y = 0; y < h; y++) {
          Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + y * d.Stride), ligne, 0, w * 4);
          for (int x = 0; x < w; x++) a[y * w + x] = ligne[x * 4 + 3];
        }
        bmp.UnlockBits(d);
      }
      int[] lab = new int[w * h]; int[] pile = new int[w * h];
      int mini = (int)(aireMini * w * h); int id = 0;
      Resultat R = new Resultat(); R.Largeur = w; R.Hauteur = h;
      List<Zone> Z = new List<Zone>();
      for (int s = 0; s < w * h; s++) {
        if (a[s] >= seuil || lab[s] != 0) continue;
        id++; int n = 0, aire = 0; pile[n++] = s; lab[s] = id;
        int x0 = w, y0 = h, x1 = -1, y1 = -1;
        while (n > 0) {
          int p = pile[--n]; int y = p / w, x = p - y * w; aire++;
          if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
          if (x > 0     && a[p - 1] < seuil && lab[p - 1] == 0) { lab[p - 1] = id; pile[n++] = p - 1; }
          if (x < w - 1 && a[p + 1] < seuil && lab[p + 1] == 0) { lab[p + 1] = id; pile[n++] = p + 1; }
          if (y > 0     && a[p - w] < seuil && lab[p - w] == 0) { lab[p - w] = id; pile[n++] = p - w; }
          if (y < h - 1 && a[p + w] < seuil && lab[p + w] == 0) { lab[p + w] = id; pile[n++] = p + w; }
        }
        if (x0 == 0 || y0 == 0 || x1 == w - 1 || y1 == h - 1) { if (aire >= mini) R.NbBord++; continue; }
        if (aire < mini) { R.NbPetites++; continue; }
        Zone z = new Zone(); z.X0 = x0; z.Y0 = y0; z.X1 = x1; z.Y1 = y1; z.Aire = aire;
        z.Remplissage = aire / (double)((x1 - x0 + 1) * (y1 - y0 + 1));
        Coins(z, lab, id, w);
        Z.Add(z);
      }
      Z.Sort(delegate(Zone p, Zone q) { return q.Aire.CompareTo(p.Aire); });
      R.Zones = Z.ToArray();
      return R;
    }
    static void Droite(List<double> t, List<double> v, out double a, out double b, out double rms) {
      List<double> T = new List<double>(t), V = new List<double>(v);
      a = 0; b = 0; rms = 0;
      for (int passe = 0; passe < 3; passe++) {
        int n = T.Count; if (n < 2) return;
        double st = 0, sv = 0, stt = 0, stv = 0;
        for (int i = 0; i < n; i++) { st += T[i]; sv += V[i]; stt += T[i] * T[i]; stv += T[i] * V[i]; }
        double den = n * stt - st * st;
        a = den == 0 ? 0 : (n * stv - st * sv) / den; b = (sv - a * st) / n;
        double s2 = 0;
        for (int i = 0; i < n; i++) { double e = V[i] - (a * T[i] + b); s2 += e * e; }
        rms = Math.Sqrt(s2 / n);
        double lim = Math.Max(1.5, 2 * rms);
        List<double> T2 = new List<double>(), V2 = new List<double>();
        for (int i = 0; i < n; i++) if (Math.Abs(V[i] - (a * T[i] + b)) <= lim) { T2.Add(T[i]); V2.Add(V[i]); }
        T = T2; V = V2;
      }
    }
    static void Coins(Zone z, int[] lab, int id, int w) {
      int L = z.X1 - z.X0 + 1, H = z.Y1 - z.Y0 + 1;
      int[] haut = new int[L], bas = new int[L], gauche = new int[H], droite = new int[H];
      for (int i = 0; i < L; i++) { haut[i] = int.MaxValue; bas[i] = -1; }
      for (int i = 0; i < H; i++) { gauche[i] = int.MaxValue; droite[i] = -1; }
      for (int y = z.Y0; y <= z.Y1; y++) for (int x = z.X0; x <= z.X1; x++) {
        if (lab[y * w + x] != id) continue;
        int i = x - z.X0, j = y - z.Y0;
        if (y < haut[i]) haut[i] = y; if (y > bas[i]) bas[i] = y;
        if (x < gauche[j]) gauche[j] = x; if (x > droite[j]) droite[j] = x;
      }
      List<double> a1 = new List<double>(), b1 = new List<double>(), b2 = new List<double>();
      for (int i = L / 5; i <= L * 4 / 5; i++) if (bas[i] >= 0) { a1.Add(z.X0 + i); b1.Add(haut[i]); b2.Add(bas[i]); }
      List<double> a2 = new List<double>(), g = new List<double>(), d = new List<double>();
      for (int j = H / 5; j <= H * 4 / 5; j++) if (droite[j] >= 0) { a2.Add(z.Y0 + j); g.Add(gauche[j]); d.Add(droite[j]); }
      double ah, bh, rh, ab, bb, rb, ag, bg, rg, ad, bd, rd;
      Droite(a1, b1, out ah, out bh, out rh); Droite(a1, b2, out ab, out bb, out rb);
      Droite(a2, g, out ag, out bg, out rg);  Droite(a2, d, out ad, out bd, out rd);
      Inter(ah, bh, ag, bg, out z.CX[0], out z.CY[0]);
      Inter(ah, bh, ad, bd, out z.CX[1], out z.CY[1]);
      Inter(ab, bb, ad, bd, out z.CX[2], out z.CY[2]);
      Inter(ab, bb, ag, bg, out z.CX[3], out z.CY[3]);
      z.Residu = Math.Max(Math.Max(rh, rb), Math.Max(rg, rd));
      double[] rx = { z.X0, z.X1, z.X1, z.X0 }, ry = { z.Y0, z.Y0, z.Y1, z.Y1 };
      for (int i = 0; i < 4; i++) z.Ecart = Math.Max(z.Ecart, Math.Max(Math.Abs(z.CX[i] - rx[i]), Math.Abs(z.CY[i] - ry[i])));
    }
    static void Inter(double a1, double b1, double a2, double b2, out double x, out double y) {
      x = (a2 * b1 + b2) / (1 - a1 * a2); y = a1 * x + b1;
    }
  }
}
'@
}

$script:Inv = [Globalization.CultureInfo]::InvariantCulture
$script:SeuilEcart = 5.0   # au-dela de cet ecart (px), l'ecran est considere de biais
$script:Fr = ((Get-UICulture).TwoLetterISOLanguageName -eq 'fr')
$script:AttrMode = @{ thumb = 'ifSubset="boxorthumb:thumb"'; boxart = 'ifSubset="boxorthumb:boxart"' }
$script:OrdreSupport = @('boxart', 'thumb')   # l'ordre des lignes d'une option : la valeur par defaut du theme en dernier
$script:FichiersDefaut = @('_default', '_default16', 'arcade', 'computers', 'extension', 'pinball', 'port', 'portable', 'auto-collection', 'custom-collection', 'retrobat')

function T([string]$fr, [string]$en) { if ($script:Fr) { $fr } else { $en } }
function N4([double]$v) { $v.ToString('0.0000', $script:Inv) }

# ---------------------------------------------------------------- reglages connus de la vue
$script:Def = @(
    @{ P = 0; Cle = 'salon_video_pos';        Type = 'nn';   Fr = 'Vidéo : centre (x y)';                     En = 'Video: centre (x y)' }
    @{ P = 0; Cle = 'salon_video_taille';     Type = 'nn';   Fr = 'Vidéo : largeur hauteur';                  En = 'Video: width height' }
    @{ P = 0; Cle = 'salon_video_etiree';     Type = 'bool'; Fr = 'Vidéo étirée pour remplir l''écran';       En = 'Video stretched to fill the screen' }
    @{ P = 0; Cle = 'salon_capture_pos';      Type = 'nn';   Fr = 'Capture ailleurs : centre';                En = 'Screenshot elsewhere: centre' }
    @{ P = 0; Cle = 'salon_capture_taille';   Type = 'nn';   Fr = 'Capture ailleurs : largeur hauteur';       En = 'Screenshot elsewhere: width height' }
    @{ P = 0; Cle = 'salon_ecran2';           Type = 'bool'; Fr = '2e écran (consoles reliées)';              En = '2nd screen (linked consoles)' }
    @{ P = 0; Cle = 'salon_video2_pos';       Type = 'nn';   Fr = '2e écran : centre';                        En = '2nd screen: centre' }
    @{ P = 0; Cle = 'salon_video2_taille';    Type = 'nn';   Fr = '2e écran : largeur hauteur';               En = '2nd screen: width height' }
    @{ P = 1; Cle = 'salon_coin_hg';          Type = 'nn';   Fr = 'Coin haut gauche (px)';                    En = 'Top-left corner (px)';     Forme = 2 }
    @{ P = 1; Cle = 'salon_coin_hd';          Type = 'nn';   Fr = 'Coin haut droit (px)';                     En = 'Top-right corner (px)';    Forme = 2 }
    @{ P = 1; Cle = 'salon_coin_bd';          Type = 'nn';   Fr = 'Coin bas droit (px)';                      En = 'Bottom-right corner (px)'; Forme = 2 }
    @{ P = 1; Cle = 'salon_coin_bg';          Type = 'nn';   Fr = 'Coin bas gauche (px)';                     En = 'Bottom-left corner (px)';  Forme = 2 }
    @{ P = 1; Cle = 'salon_coins_proportions'; Type = 'n';   Fr = 'Proportions (0 remplit, 1 gardées)';       En = 'Proportions (0 fill, 1 keep)'; Forme = 2 }
    @{ P = 1; Cle = 'salon_persp_angle_x';    Type = 'n';    Fr = 'Angle autour de l''axe vertical (°)';      En = 'Angle around vertical axis (°)';   Forme = 1 }
    @{ P = 1; Cle = 'salon_persp_angle_y';    Type = 'n';    Fr = 'Angle autour de l''axe horizontal (°)';    En = 'Angle around horizontal axis (°)'; Forme = 1 }
    @{ P = 1; Cle = 'salon_persp_profondeur'; Type = 'n';    Fr = 'Profondeur (1 = normale)';                 En = 'Depth (1 = default)';      Forme = 1 }
    @{ P = 2; Cle = 'salon_disque_tourne';    Type = 'bool'; Fr = 'Le disque tourne';                         En = 'The disc spins';           PasDefaut = $true }
    @{ P = 2; Cle = 'salon_support_mixte';    Type = 'bool'; Fr = 'Disques et cartouches mélangés';           En = 'Mixed discs and cartridges'; PasDefaut = $true }
    @{ P = 2; Cle = 'salon_disque_depart';    Type = 'n';    Fr = 'x de départ, caché derrière la boîte';     En = 'Start x, hidden behind the box' }
    @{ P = 2; Cle = 'salon_disque_x';         Type = 'dn';   Fr = 'x une fois sorti';                         En = 'x once out' }
    @{ P = 2; Cle = 'salon_disque_y';         Type = 'dn';   Fr = 'Hauteur du centre';                        En = 'Centre height' }
    @{ P = 2; Cle = 'salon_disque_taille';    Type = 'dnn';  Fr = 'Taille (largeur hauteur)';                 En = 'Size (width height)' }
    @{ P = 2; Cle = 'salon_support_umd';      Type = 'bool'; Fr = 'UMD : seul le disque tourne';              En = 'UMD: only the disc spins' }
    @{ P = 2; Cle = 'salon_umd_cx';           Type = 'n';    Fr = 'UMD : centre horizontal';                  En = 'UMD: horizontal centre' }
    @{ P = 2; Cle = 'salon_umd_cy';           Type = 'n';    Fr = 'UMD : centre vertical';                    En = 'UMD: vertical centre' }
    @{ P = 2; Cle = 'salon_umd_rayon';        Type = 'n';    Fr = 'UMD : rayon qui tourne';                   En = 'UMD: spinning radius' }
    @{ P = 2; Cle = 'salon_umd_rayon_centre'; Type = 'n';    Fr = 'UMD : rayon du centre fixe';               En = 'UMD: fixed centre radius' }
    @{ P = 3; Cle = 'salon_couleur';          Type = 'coul'; Fr = 'Couleur multipliée';                       En = 'Multiplied colour' }
    @{ P = 3; Cle = 'salon_saturation';       Type = 'n';    Fr = 'Saturation (1 normale, 0 noir et blanc)';  En = 'Saturation (1 normal, 0 black and white)' }
    @{ P = 3; Cle = 'salon_calque';           Type = 'img';  Fr = 'Calque posé sur l''écran';                 En = 'Overlay on the screen' }
)

# ---------------------------------------------------------------- mesure
function Test-EcranDeBiais($zone) { $zone.Ecart -gt $script:SeuilEcart }

function Get-Coins($res, $zone, [int]$marge) {
    $sx = 1920.0 / $res.Largeur; $sy = 1080.0 / $res.Hauteur
    $dx = @(-1, 1, 1, -1); $dy = @(-1, -1, 1, 1); $sortie = @()
    for ($i = 0; $i -lt 4; $i++) {
        $x = [int][Math]::Round($zone.CX[$i] * $sx + $dx[$i] * $marge)
        $y = [int][Math]::Round($zone.CY[$i] * $sy + $dy[$i] * $marge)
        $sortie += "$x $y"
    }
    return $sortie
}

function Get-PosTaille($res, $zone, [int]$marge) {
    $w = [double]$res.Largeur; $h = [double]$res.Hauteur
    @{ Pos = (N4 (($zone.X0 + $zone.X1) / 2.0 / $w)) + ' ' + (N4 (($zone.Y0 + $zone.Y1) / 2.0 / $h))
       Taille = (N4 (($zone.X1 - $zone.X0 + 2 * $marge) / $w)) + ' ' + (N4 (($zone.Y1 - $zone.Y0 + 2 * $marge) / $h)) }
}

# ---------------------------------------------------------------- lecture et fusion du XML
function Read-Texte([string]$p) { if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllText($p, (New-Object Text.UTF8Encoding($false))) } else { $null } }

function Get-LignesXml([string]$t) {
    if (-not $t) { return @() }
    foreach ($m in [regex]::Matches($t, '(?m)^[ \t]*<(salon_[a-z0-9_]+)(\s[^>]*)?>([^<]*)</\1>[ \t]*\r?$')) {
        [pscustomobject]@{ Cle = $m.Groups[1].Value; Attr = $m.Groups[2].Value.Trim(); Valeur = $m.Groups[3].Value
                           Debut = $m.Index; Longueur = $m.Length; VDebut = $m.Groups[3].Index; VLong = $m.Groups[3].Length }
    }
}

function Merge-SalonXml([string]$texte, $souhait, $geres) {
    # souhait : lignes voulues (Cle, Attr, Valeur) ; geres : cles que l'outil a le droit de modifier.
    # Une ligne geree absente du souhait est retiree ; une cle portant une autre condition est laissee telle quelle.
    if ([string]::IsNullOrEmpty($texte)) {
        $texte = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<theme>`n`t<formatVersion>7</formatVersion>`n`t<variables>`n`t</variables>`n</theme>`n"
    }
    $nl = $(if ($texte.Contains("`r`n")) { "`r`n" } else { "`n" })
    $f = @([regex]::Matches($texte, '(?m)^[ \t]*</variables>'))
    if ($f.Count -ne 1) { throw (T 'Bloc <variables> introuvable : fichier à corriger à la main.' 'No <variables> block: edit this file by hand.') }
    $lignes = @(Get-LignesXml $texte)
    $connus = @($script:AttrMode.Values) + ''
    $bloques = @($lignes | Where-Object { $connus -notcontains $_.Attr } | ForEach-Object { $_.Cle } | Sort-Object -Unique)
    $vus = @{}
    foreach ($l in $lignes) {
        if ($geres -notcontains $l.Cle -or $bloques -contains $l.Cle) { continue }
        $k = "$($l.Cle)|$($l.Attr)"
        if ($vus[$k]) { throw (T "Plusieurs lignes $($l.Cle) : fichier à corriger à la main." "Several $($l.Cle) lines: edit this file by hand.") }
        $vus[$k] = $true
    }
    $ajouts = ''
    foreach ($s in $souhait) {
        if ($bloques -contains $s.Cle) { continue }
        if (-not $vus["$($s.Cle)|$($s.Attr)"]) {
            $a = $(if ($s.Attr) { " $($s.Attr)" } else { '' })
            $ajouts += "`t`t<$($s.Cle)$a>$($s.Valeur)</$($s.Cle)>$nl"
        }
    }
    $texte = $texte.Substring(0, $f[0].Index) + $ajouts + $texte.Substring($f[0].Index)
    foreach ($l in @($lignes | Sort-Object Debut -Descending)) {
        if ($geres -notcontains $l.Cle -or $bloques -contains $l.Cle) { continue }
        $s = @($souhait | Where-Object { $_.Cle -eq $l.Cle -and $_.Attr -eq $l.Attr })
        if ($s.Count -gt 0) {
            $texte = $texte.Substring(0, $l.VDebut) + $s[0].Valeur + $texte.Substring($l.VDebut + $l.VLong)
        } else {
            $fin = $l.Debut + $l.Longueur
            if ($fin -lt $texte.Length -and $texte[$fin] -eq "`n") { $fin++ }
            $texte = $texte.Substring(0, $l.Debut) + $texte.Substring($fin)
        }
    }
    [void][xml]$texte
    return [pscustomobject]@{ Texte = $texte; Bloques = $bloques }
}

function Write-SalonXml([string]$xml, [string]$contenu) {
    $enc = New-Object Text.UTF8Encoding($false)
    if (Test-Path -LiteralPath $xml) {
        $sv = Join-Path (Split-Path -LiteralPath $xml) '_sauvegardes_calage'
        if (-not (Test-Path -LiteralPath $sv)) { [void][IO.Directory]::CreateDirectory($sv) }
        $nom = [IO.Path]::GetFileNameWithoutExtension($xml) + '_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.xml'
        [IO.File]::Copy($xml, (Join-Path $sv $nom), $true)
    }
    $tmp = "$xml.tmp"
    [IO.File]::WriteAllText($tmp, $contenu, $enc)
    if (Test-Path -LiteralPath $xml) { [IO.File]::Replace($tmp, $xml, [NullString]::Value) } else { [IO.File]::Move($tmp, $xml) }
}

# ---------------------------------------------------------------- champs de la fenetre
function Set-Ligne([string]$cle, [bool]$cochee, $v1, $v2) {
    $r = $script:Lignes[$cle]; if (-not $r) { return }
    $r.Case.Checked = $cochee
    switch ($r.Type) {
        'bool' { $r.C1.SelectedIndex = $(if ("$v1" -eq 'false') { 1 } else { 0 }) }
        default { $r.C1.Text = "$v1"; if ($r.C2) { $r.C2.Text = "$v2" } }
    }
}

function ConvertTo-Valeur($r, [string]$v) {
    $v = $v.Trim() -replace ',', '.' -replace '\s+', ' '
    $n = '-?\d+(\.\d+)?'
    $ok = switch ($r.Type) {
        'n'    { $v -match "^$n$" }
        'dn'   { $v -match "^$n$" }
        'nn'   { $v -match "^$n $n$" }
        'dnn'  { $v -match "^$n $n$" }
        default { $true }
    }
    if (-not $ok) { throw (T "Valeur invalide pour $($r.Cle) : « $v »" "Invalid value for $($r.Cle): '$v'") }
    $v
}

function Get-Souhait {
    # Traduit les champs de la fenetre en lignes voulues et en liste de cles modifiables
    $e = $script:Etat; $souhait = New-Object Collections.ArrayList; $geres = New-Object Collections.ArrayList
    $defaut = $script:FichiersDefaut -contains ([IO.Path]::GetFileNameWithoutExtension($e.Xml))
    $forme = $script:U.Forme.SelectedIndex
    function Ajout($cle, $attr, $val) { [void]$souhait.Add([pscustomobject]@{ Cle = $cle; Attr = $attr; Valeur = $val }) }
    [void]$geres.Add('salon_perspective')
    if ($forme -ne 0) { Ajout 'salon_perspective' '' "$forme" } elseif ($e.AvaitPerspective) { Ajout 'salon_perspective' '' '0' }
    foreach ($d in $script:Def) {
        $r = $script:Lignes[$d.Cle]
        if ($defaut -and $d.PasDefaut) { continue }
        if ($d.Forme -and $d.Forme -ne $forme) { continue }
        [void]$geres.Add($d.Cle)
        if ($d.Cle -in 'salon_capture_pos', 'salon_capture_taille') {
            $source = $(if ($d.Cle -eq 'salon_capture_pos') { 'salon_video_pos' } else { 'salon_video_taille' })
            $rs = $script:Lignes[$source]
            if ($r.Case.Checked) { Ajout $d.Cle '' (ConvertTo-Valeur $r $r.C1.Text) }
            elseif ($rs.Case.Checked) { Ajout $d.Cle '' (ConvertTo-Valeur $rs $rs.C1.Text) }
            continue
        }
        if (-not $r.Case.Checked) { continue }
        switch ($r.Type) {
            'bool' { Ajout $d.Cle '' $(if ($r.C1.SelectedIndex -eq 1) { 'false' } else { 'true' }) }
            { $_ -in 'dn', 'dnn' } {
                $t2 = $r.C1.Text.Trim(); $t3 = $r.C2.Text.Trim()
                $v2 = $(if ($t2) { ConvertTo-Valeur $r $t2 }); $v3 = $(if ($t3) { ConvertTo-Valeur $r $t3 })
                if (-not $v2 -and -not $v3) { break }
                if ($v2 -eq $v3 -and -not $e.Modes[$d.Cle]) { Ajout $d.Cle '' $v2; break }
                foreach ($mode in $script:OrdreSupport) {
                    $val = $(if ($mode -eq 'thumb') { $v2 } else { $v3 })
                    if ($val) { Ajout $d.Cle $script:AttrMode[$mode] $val }
                }
            }
            'coul' {
                $v = $r.C1.Text.Trim()
                if ($v -notmatch '^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$') { throw (T "Couleur invalide : « $v » (6 ou 8 chiffres hexadécimaux)" "Invalid colour: '$v' (6 or 8 hex digits)") }
                Ajout $d.Cle '' $v
            }
            'img' { Ajout $d.Cle '' $r.C1.Text.Trim() }
            default { Ajout $d.Cle '' (ConvertTo-Valeur $r $r.C1.Text) }
        }
    }
    @{ Souhait = @($souhait); Geres = @($geres) }
}

function Invoke-Mesure {
    # Remplit les champs de position a partir de la zone choisie
    $e = $script:Etat; $u = $script:U
    if (-not $e -or -not $e.Res -or $e.Res.Zones.Count -eq 0 -or $u.Zone.SelectedIndex -lt 0) { return }
    $old = $script:Maj; $script:Maj = $true
    $z = $e.Res.Zones[$u.Zone.SelectedIndex]; $marge = [int]$u.Marge.Value
    $m = Get-PosTaille $e.Res $z $marge
    Set-Ligne 'salon_video_pos' $true $m.Pos; Set-Ligne 'salon_video_taille' $true $m.Taille
    Set-Ligne 'salon_capture_pos' $false ''; Set-Ligne 'salon_capture_taille' $false ''
    $c = Get-Coins $e.Res $z $marge
    Set-Ligne 'salon_coin_hg' $true $c[0]; Set-Ligne 'salon_coin_hd' $true $c[1]; Set-Ligne 'salon_coin_bd' $true $c[2]; Set-Ligne 'salon_coin_bg' $true $c[3]
    if (-not $script:Lignes['salon_coins_proportions'].Case.Checked) { Set-Ligne 'salon_coins_proportions' $true '0' }
    $u.Forme.SelectedIndex = $(if (Test-EcranDeBiais $z) { 2 } else { 0 })
    if ($u.Zone2.SelectedIndex -gt 0 -and $e.Res.Zones[$u.Zone2.SelectedIndex - 1] -ne $z) {
        $m2 = Get-PosTaille $e.Res $e.Res.Zones[$u.Zone2.SelectedIndex - 1] $marge
        Set-Ligne 'salon_ecran2' $true 'true'; Set-Ligne 'salon_video2_pos' $true $m2.Pos; Set-Ligne 'salon_video2_taille' $true $m2.Taille
    } elseif ($script:Lignes['salon_ecran2'].Case.Checked) {
        Set-Ligne 'salon_ecran2' $true 'false'
    }
    $script:Maj = $old
}

function ZoneTexte($z, $i) { '{0}.  x {1}-{2}  y {3}-{4}  ({5:0.0} %)' -f ($i + 1), $z.X0, $z.X1, $z.Y0, $z.Y1, (100.0 * $z.Aire / ($script:Etat.Res.Largeur * $script:Etat.Res.Hauteur)) }

function Update-Vue {
    if ($script:Maj -or -not $script:Etat) { return }
    $e = $script:Etat; $u = $script:U
    foreach ($d in $script:Def) {
        $r = $script:Lignes[$d.Cle]; $actif = $r.Case.Enabled -and $r.Case.Checked
        $r.C1.Enabled = $actif; if ($r.C2) { $r.C2.Enabled = $actif }; if ($r.Btn) { $r.Btn.Enabled = $actif }
    }
    # Apercu
    if ($e.Image) {
        $W = 720; $H = 405; $b = New-Object Drawing.Bitmap($W, $H)
        $g = [Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'
        $g.Clear([Drawing.Color]::FromArgb(255, 0, 200)); $g.DrawImage($e.Image, 0, 0, $W, $H)
        function Cadre($cle1, $cle2, $couleur) {
            try {
                $p = ($script:Lignes[$cle1].C1.Text.Trim() -replace ',', '.') -split '\s+' | ForEach-Object { [double]::Parse($_, $script:Inv) }
                $s = ($script:Lignes[$cle2].C1.Text.Trim() -replace ',', '.') -split '\s+' | ForEach-Object { [double]::Parse($_, $script:Inv) }
                $st = New-Object Drawing.Pen($couleur, 2)
                $g.DrawRectangle($st, [int](($p[0] - $s[0] / 2) * $W), [int](($p[1] - $s[1] / 2) * $H), [int]($s[0] * $W), [int]($s[1] * $H))
                $st.Dispose()
            } catch { }
        }
        if ($u.Forme.SelectedIndex -eq 2) {
            try {
                $pts = 'salon_coin_hg', 'salon_coin_hd', 'salon_coin_bd', 'salon_coin_bg' | ForEach-Object {
                    $v = ($script:Lignes[$_].C1.Text.Trim() -replace ',', '.') -split '\s+' | ForEach-Object { [double]::Parse($_, $script:Inv) }
                    New-Object Drawing.PointF(([single]($v[0] * $W / 1920)), ([single]($v[1] * $H / 1080)))
                }
                $st = New-Object Drawing.Pen([Drawing.Color]::Lime, 2); $g.DrawPolygon($st, [Drawing.PointF[]]$pts); $st.Dispose()
            } catch { }
        } elseif ($script:Lignes['salon_video_pos'].Case.Checked) { Cadre 'salon_video_pos' 'salon_video_taille' ([Drawing.Color]::Lime) }
        if ($script:Lignes['salon_capture_pos'].Case.Checked) { Cadre 'salon_capture_pos' 'salon_capture_taille' ([Drawing.Color]::Orange) }
        if ($script:Lignes['salon_ecran2'].Case.Checked -and $script:Lignes['salon_ecran2'].C1.SelectedIndex -eq 0) { Cadre 'salon_video2_pos' 'salon_video2_taille' ([Drawing.Color]::Cyan) }
        $g.Dispose()
        if ($u.Image.Image) { $u.Image.Image.Dispose() }
        $u.Image.Image = $b
    }
    # Messages
    $av = @()
    if ($e.Res) {
        if ($e.Res.Largeur -ne 1920 -or $e.Res.Hauteur -ne 1080) { $av += (T "Image de $($e.Res.Largeur)x$($e.Res.Hauteur) : le thème attend 1920x1080." "Image is $($e.Res.Largeur)x$($e.Res.Hauteur): the theme expects 1920x1080.") }
        if ($e.Res.Zones.Count -eq 0) { $av += (T 'Aucune zone transparente exploitable dans le PNG : détoure d''abord l''écran.' 'No usable transparent area in the PNG: cut out the screen first.') }
        elseif ($u.Zone.SelectedIndex -ge 0) {
            $z = $e.Res.Zones[$u.Zone.SelectedIndex]
            $det = $(if (Test-EcranDeBiais $z) { T 'Mesure : écran de biais' 'Measure: angled screen' } else { T 'Mesure : rectangle de face' 'Measure: front-facing rectangle' })
            $av += "$det ($($z.Ecart.ToString('0.0', $script:Inv)) px)"
            if ($z.Residu -gt 3 -or $z.Remplissage -lt 0.75) { $av += (T 'Forme irrégulière : contrôle le contour vert.' 'Irregular shape: check the green outline.') }
            if ($e.Res.Zones.Count -gt 1 -and $u.Zone2.SelectedIndex -le 0) { $av += (T "$($e.Res.Zones.Count) zones transparentes : vérifie l''écran choisi." "$($e.Res.Zones.Count) transparent areas: check the selected screen.") }
        }
    } else { $av += (T 'Pas de décor PNG : réglages seuls.' 'No background PNG: settings only.') }
    if ($script:FichiersDefaut -contains ([IO.Path]::GetFileNameWithoutExtension($e.Xml))) { $av += (T 'Fichier par défaut : rotation et support mixte non modifiables ici, ils remplaceraient le réglage de chaque système.' 'Default file: rotation and mixed media cannot be changed here, they would override each system.') }
    try {
        $x = Get-Souhait
        $res = Merge-SalonXml $e.Avant $x.Souhait $x.Geres
        $e.Neuf = $res.Texte
        if ($res.Bloques.Count -gt 0) { $av += (T "Ligne conditionnelle conservée telle quelle : $($res.Bloques -join ', ')" "Conditional line left as is: $($res.Bloques -join ', ')") }
        $identique = ($null -ne $e.Avant -and $e.Neuf -ceq $e.Avant)
        $u.Plan.Text = ($e.Neuf -replace "`r?`n", "`r`n")
        $u.Ecrire.Enabled = -not $identique
        if ($identique) { $av += (T 'Aucun changement à écrire.' 'Nothing to write.') }
    } catch {
        $e.Neuf = $null; $u.Plan.Text = $_.Exception.Message; $u.Ecrire.Enabled = $false
    }
    $u.Info.Text = $av -join "`r`n"
}

function Open-Decor([string]$chemin) {
    # Accepte un PNG, un XML, ou le nom d'un XML a creer
    $u = $script:U
    $png = [IO.Path]::ChangeExtension($chemin, '.png'); $xml = [IO.Path]::ChangeExtension($chemin, '.xml')
    $res = $null; $img = $null
    if (Test-Path -LiteralPath $png) {
        $res = [CalageSalon.Mesure]::Analyser($png, 128, 0.002)
        $fs = [IO.File]::OpenRead($png)
        try { $src = [Drawing.Image]::FromStream($fs); $img = New-Object Drawing.Bitmap($src); $src.Dispose() } finally { $fs.Dispose() }
    }
    if ($script:Etat -and $script:Etat.Image) { $script:Etat.Image.Dispose() }
    if ($u.Image.Image) { $u.Image.Image.Dispose(); $u.Image.Image = $null }
    $avant = Read-Texte $xml
    $lignes = @(Get-LignesXml $avant)
    $script:Etat = @{ Res = $res; Image = $img; Xml = $xml; Avant = $avant; Neuf = $null; Modes = @{}; AvaitPerspective = $false }
    $e = $script:Etat
    $script:Maj = $true
    $u.Chemin.Text = $xml
    $defaut = $script:FichiersDefaut -contains ([IO.Path]::GetFileNameWithoutExtension($xml))
    foreach ($d in $script:Def) {
        $r = $script:Lignes[$d.Cle]
        $r.Case.Enabled = -not ($defaut -and $d.PasDefaut)
        $ici = @($lignes | Where-Object { $_.Cle -eq $d.Cle })
        if ($d.Type -in 'dn', 'dnn') {
            $plain = @($ici | Where-Object { -not $_.Attr })
            $th = @($ici | Where-Object { $_.Attr -eq $script:AttrMode.thumb }); $bo = @($ici | Where-Object { $_.Attr -eq $script:AttrMode.boxart })
            $e.Modes[$d.Cle] = ($th.Count -gt 0 -or $bo.Count -gt 0)
            if ($plain.Count) { Set-Ligne $d.Cle $true $plain[0].Valeur $plain[0].Valeur }
            else { Set-Ligne $d.Cle ($ici.Count -gt 0) $(if ($th.Count) { $th[0].Valeur } else { '' }) $(if ($bo.Count) { $bo[0].Valeur } else { '' }) }
        } else {
            $sans = @($ici | Where-Object { -not $_.Attr })
            if ($sans.Count) { Set-Ligne $d.Cle $true $sans[0].Valeur } else { Set-Ligne $d.Cle $false $(if ($d.Type -eq 'bool') { 'true' } else { '' }) }
        }
    }
    # Capture : cochee seulement si elle differe de la video
    foreach ($p in @(@('salon_capture_pos', 'salon_video_pos'), @('salon_capture_taille', 'salon_video_taille'))) {
        $c = $script:Lignes[$p[0]]; $v = $script:Lignes[$p[1]]
        if ($c.Case.Checked -and $v.Case.Checked -and $c.C1.Text -ceq $v.C1.Text) { Set-Ligne $p[0] $false '' }
    }
    $persp = @($lignes | Where-Object { $_.Cle -eq 'salon_perspective' -and -not $_.Attr })
    $e.AvaitPerspective = ($persp.Count -gt 0)
    $u.Forme.SelectedIndex = $(if ($persp.Count -and $persp[0].Valeur -in '1', '2') { [int]$persp[0].Valeur } else { 0 })
    $u.Zone.Items.Clear(); $u.Zone2.Items.Clear()
    [void]$u.Zone2.Items.Add((T 'Aucun' 'None')); $u.Zone2.SelectedIndex = 0
    $avecZones = ($res -and $res.Zones.Count -gt 0)
    $u.Mesurer.Enabled = $avecZones; $u.Zone.Enabled = $avecZones; $u.Zone2.Enabled = $avecZones
    if ($avecZones) {
        for ($i = 0; $i -lt $res.Zones.Count; $i++) { $t = ZoneTexte $res.Zones[$i] $i; [void]$u.Zone.Items.Add($t); [void]$u.Zone2.Items.Add($t) }
        $u.Zone.SelectedIndex = 0
        if ($res.Zones.Count -ge 2) {
            $a = $res.Zones[0]; $b = $res.Zones[1]
            if ($b.Aire -ge 0.7 * $a.Aire -and $b.Y0 -le $a.Y1 -and $b.Y1 -ge $a.Y0) {
                if ($a.X0 -lt $b.X0) { $u.Zone2.SelectedIndex = 2 } else { $u.Zone.SelectedIndex = 1; $u.Zone2.SelectedIndex = 1 }
            }
        }
        if (-not $script:Lignes['salon_video_pos'].Case.Checked) {
            Invoke-Mesure
            if (-not $script:Lignes['salon_video_etiree'].Case.Checked) {
                $z = $res.Zones[$u.Zone.SelectedIndex]; $ratio = ($z.X1 - $z.X0) / [double]($z.Y1 - $z.Y0)
                Set-Ligne 'salon_video_etiree' $true $(if ($ratio -ge 1.15 -and $ratio -le 1.5) { 'true' } else { 'false' })
            }
        }
    }
    $script:Maj = $false
    Update-Vue
}

function New-Interface {
    $f = New-Object Windows.Forms.Form
    $f.Text = T 'Réglages du décor - vue Retrofist Nostalgia' 'Background settings - Retrofist Nostalgia view'
    $f.ClientSize = New-Object Drawing.Size(1240, 700); $f.FormBorderStyle = 'FixedSingle'; $f.MaximizeBox = $false; $f.StartPosition = 'CenterScreen'
    function Ctrl($parent, $type, $x, $y, $w, $h, $texte) {
        $c = New-Object "Windows.Forms.$type"; $c.Left = $x; $c.Top = $y; $c.Width = $w; $c.Height = $h
        if ($null -ne $texte) { $c.Text = $texte }; $parent.Controls.Add($c); $c
    }
    $U = @{}
    $U.Choisir = Ctrl $f Button 12 12 200 30 (T 'Ouvrir un décor (PNG ou XML)...' 'Open a background (PNG or XML)...')
    $U.Nouveau = Ctrl $f Button 220 12 200 30 (T 'Nouveau XML sans décor...' 'New XML without background...')
    $U.Chemin = Ctrl $f Label 430 19 800 20 (T 'Le PNG doit avoir son écran transparent.' 'The PNG must have a transparent screen.')
    $U.Image = Ctrl $f PictureBox 12 52 720 405 $null
    $U.Image.SizeMode = 'Zoom'; $U.Image.BackColor = [Drawing.Color]::FromArgb(32, 32, 32); $U.Image.BorderStyle = 'FixedSingle'
    $U.Plan = Ctrl $f TextBox 12 465 720 223 $null
    $U.Plan.Multiline = $true; $U.Plan.ReadOnly = $true; $U.Plan.ScrollBars = 'Vertical'; $U.Plan.Font = New-Object Drawing.Font('Consolas', 9)
    $Tab = Ctrl $f TabControl 745 52 483 510 $null
    $pages = @()
    foreach ($n in (T 'Écran' 'Screen'), 'Perspective', (T 'Support' 'Media'), 'Image') { $p = New-Object Windows.Forms.TabPage; $p.Text = $n; $Tab.TabPages.Add($p); $pages += $p }
    $p0 = $pages[0]
    [void](Ctrl $p0 Label 8 10 120 18 (T 'Écran principal' 'Main screen'))
    $U.Zone = Ctrl $p0 ComboBox 130 7 335 24 $null; $U.Zone.DropDownStyle = 'DropDownList'
    [void](Ctrl $p0 Label 8 40 120 18 (T '2e zone' '2nd area'))
    $U.Zone2 = Ctrl $p0 ComboBox 130 37 335 24 $null; $U.Zone2.DropDownStyle = 'DropDownList'
    [void](Ctrl $p0 Label 8 72 120 18 (T 'Marge (px)' 'Margin (px)'))
    $U.Marge = Ctrl $p0 NumericUpDown 130 69 60 24 $null; $U.Marge.Minimum = 0; $U.Marge.Maximum = 10; $U.Marge.Value = 2
    $U.Mesurer = Ctrl $p0 Button 205 67 260 26 (T 'Mesurer depuis le PNG' 'Measure from the PNG')
    $p1 = $pages[1]
    [void](Ctrl $p1 Label 8 10 120 18 (T 'Forme de l''écran' 'Screen shape'))
    $U.Forme = Ctrl $p1 ComboBox 130 7 335 24 $null; $U.Forme.DropDownStyle = 'DropDownList'
    [void]$U.Forme.Items.Add((T 'Rectangle, de face' 'Rectangle, front view')); [void]$U.Forme.Items.Add((T 'Par angles' 'By angles')); [void]$U.Forme.Items.Add((T 'Par les 4 coins' 'By the 4 corners'))
    $U.Forme.SelectedIndex = 0
    [void](Ctrl $pages[2] Label 262 6 96 16 (T 'Boîte 2D' '2D box')); [void](Ctrl $pages[2] Label 362 6 96 16 (T 'Boîte 3D' '3D box'))
    $y = @(104, 44, 26, 12)
    $script:Lignes = @{}
    foreach ($d in $script:Def) {
        $pg = $pages[$d.P]; $yy = $y[$d.P]; $y[$d.P] += 30
        if ($d.P -eq 1 -and -not $d.Done -and $d.Cle -eq 'salon_persp_angle_x') { $yy += 14; $y[1] += 14 }
        $r = @{ Cle = $d.Cle; Type = $d.Type; C2 = $null; Btn = $null }
        $r.Case = Ctrl $pg CheckBox 8 $yy 250 22 (T $d.Fr $d.En)
        switch ($d.Type) {
            'bool' { $r.C1 = Ctrl $pg ComboBox 262 $yy 196 24 $null; $r.C1.DropDownStyle = 'DropDownList'; [void]$r.C1.Items.Add((T 'Oui' 'Yes')); [void]$r.C1.Items.Add((T 'Non' 'No')); $r.C1.SelectedIndex = 0 }
            { $_ -in 'dn', 'dnn' } { $r.C1 = Ctrl $pg TextBox 262 $yy 96 22 ''; $r.C2 = Ctrl $pg TextBox 362 $yy 96 22 '' }
            { $_ -in 'coul', 'img' } { $r.C1 = Ctrl $pg TextBox 262 $yy 150 22 ''; $r.Btn = Ctrl $pg Button 416 ($yy - 1) 42 24 '...' }
            default { $r.C1 = Ctrl $pg TextBox 262 $yy 196 22 '' }
        }
        $script:Lignes[$d.Cle] = $r
        $r.Case.Add_CheckedChanged({ Update-Vue })
        if ($d.Type -eq 'bool') { $r.C1.Add_SelectedIndexChanged({ Update-Vue }) } else { $r.C1.Add_TextChanged({ Update-Vue }) }
        if ($r.C2) { $r.C2.Add_TextChanged({ Update-Vue }) }
    }
    $U.Info = Ctrl $f Label 745 568 483 78 ''
    $U.Ecrire = Ctrl $f Button 745 650 483 38 (T 'Écrire le fichier XML' 'Write the XML file'); $U.Ecrire.Enabled = $false
    $script:U = $U; $script:Etat = $null; $script:Maj = $false; $script:Form = $f

    $script:Lignes['salon_couleur'].Btn.Add_Click({
        $d = New-Object Windows.Forms.ColorDialog; $d.FullOpen = $true
        if ($d.ShowDialog() -eq 'OK') { $script:Lignes['salon_couleur'].C1.Text = '{0:X2}{1:X2}{2:X2}' -f $d.Color.R, $d.Color.G, $d.Color.B }
    })
    $script:Lignes['salon_calque'].Btn.Add_Click({
        if (-not $script:Etat) { return }
        $dos = Split-Path -LiteralPath $script:Etat.Xml
        $d = New-Object Windows.Forms.OpenFileDialog; $d.Filter = 'PNG|*.png'; $d.InitialDirectory = $dos
        if ($d.ShowDialog() -eq 'OK') {
            if ((Split-Path -LiteralPath $d.FileName) -ne $dos) { [void][Windows.Forms.MessageBox]::Show((T 'Le calque doit être dans le même dossier que le décor.' 'The overlay must be in the same folder as the background.')); return }
            $script:Lignes['salon_calque'].C1.Text = '${path_salon}/' + [IO.Path]::GetFileName($d.FileName)
        }
    })
    $U.Forme.Add_SelectedIndexChanged({ Update-Vue })
    $U.Zone.Add_SelectedIndexChanged({ if (-not $script:Maj) { Invoke-Mesure; Update-Vue } })
    $U.Zone2.Add_SelectedIndexChanged({ if (-not $script:Maj) { Invoke-Mesure; Update-Vue } })
    $U.Marge.Add_ValueChanged({ if ($script:Etat -and $script:Etat.Res) { Invoke-Mesure; Update-Vue } })
    $U.Mesurer.Add_Click({ Invoke-Mesure; Update-Vue })
    $U.Choisir.Add_Click({
        $d = New-Object Windows.Forms.OpenFileDialog; $d.Filter = 'PNG, XML|*.png;*.xml'
        if ($d.ShowDialog() -eq 'OK') { try { Open-Decor $d.FileName } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message) } }
    })
    $U.Nouveau.Add_Click({
        $d = New-Object Windows.Forms.SaveFileDialog; $d.Filter = 'XML|*.xml'; $d.OverwritePrompt = $false
        if ($d.ShowDialog() -eq 'OK') { try { Open-Decor $d.FileName } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message) } }
    })
    $U.Ecrire.Add_Click({
        $e = $script:Etat; if (-not $e -or -not $e.Neuf) { return }
        $existe = Test-Path -LiteralPath $e.Xml
        $msg = $(if ($existe) { T "Mettre à jour $($e.Xml) ?`n`nL'ancienne version va dans _sauvegardes_calage." "Update $($e.Xml)?`n`nThe previous version goes to _sauvegardes_calage." } else { T "Créer $($e.Xml) ?" "Create $($e.Xml)?" })
        if ([Windows.Forms.MessageBox]::Show($msg, $script:Form.Text, 'YesNo', 'Question') -ne 'Yes') { return }
        try {
            Write-SalonXml $e.Xml $e.Neuf
            $e.Avant = Read-Texte $e.Xml
            Update-Vue
            $script:U.Info.Text = T "Fichier écrit. Recharge le thème pour voir le résultat." "File written. Reload the theme to see the result."
        } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message) }
    })
    return $f
}

if (-not $CalageSansInterface) {
    try { [Windows.Forms.Application]::EnableVisualStyles(); [void](New-Interface).ShowDialog() }
    catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message) }
}
