//PRE_BEGIN
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <orbis/libkernel.h>
#ifdef PS4UI_NOPAD
#define USE_PAD 0
#else
#define USE_PAD 1
#endif
#ifdef PS4UI_NODIR
#define USE_DIR 0
#else
#define USE_DIR 1
#endif
#ifdef PS4UI_NOGD
#define USE_GD 0
#else
#define USE_GD 1
#endif
#ifdef PS4UI_NOFT
#define USE_FT 0
#else
#define USE_FT 1
#endif
#if USE_DIR
#include <dirent.h>
#endif
//PRE_END

#if USE_FT && defined(GRAPHICS_USES_FONT)
#define UI_FT 1
#else
#define UI_FT 0
#endif

#ifndef PS4UI_FONT
#define PS4UI_FONT "/app0/Gontserrat-Regular.ttf"
#endif
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL
#define FW 1920
#define FH 1080
#define MAXF 200

#define B_OPTIONS 0x0008u
#define B_UP 0x0010u
#define B_RIGHT 0x0020u
#define B_DOWN 0x0040u
#define B_LEFT 0x0080u
#define B_L1 0x0400u
#define B_R1 0x0800u
#define B_TRI 0x1000u
#define B_CIRCLE 0x2000u
#define B_CROSS 0x4000u
#define B_SQUARE 0x8000u

// ---------------------------------------------------------------- UTF-8
static unsigned u8next(const char** pp) {
  const unsigned char* p = (const unsigned char*)*pp;
  unsigned c = *p;
  if (c < 0x80) { *pp += 1; return c; }
  if ((c >> 5) == 6 && (p[1] & 0xC0) == 0x80) { *pp += 2; return ((c & 31u) << 6) | (p[1] & 63u); }
  if ((c >> 4) == 14 && (p[1] & 0xC0) == 0x80 && (p[2] & 0xC0) == 0x80) {
    *pp += 3;
    return ((c & 15u) << 12) | ((p[1] & 63u) << 6) | (p[2] & 63u);
  }
  if ((c >> 3) == 30 && (p[1] & 0xC0) == 0x80 && (p[2] & 0xC0) == 0x80 && (p[3] & 0xC0) == 0x80) {
    *pp += 4;
    return ((c & 7u) << 18) | ((p[1] & 63u) << 12) | ((p[2] & 63u) << 6) | (p[3] & 63u);
  }
  *pp += 1;
  return '?';
}

static int toCps(const char* s, unsigned* out, int mx) {
  int n = 0;
  while (*s && n < mx) out[n++] = u8next(&s);
  return n;
}

// ------------------------------------------------------- Arabic shaping
struct ArForm { unsigned short base; unsigned short iso; unsigned char kind; };
// kind: 0 = never joins, 1 = joins to the previous letter only, 2 = joins both sides
static const ArForm AR[] = {
  {0x0621, 0xFE80, 0},
  {0x0622, 0xFE81, 1}, {0x0623, 0xFE83, 1}, {0x0624, 0xFE85, 1}, {0x0625, 0xFE87, 1},
  {0x0626, 0xFE89, 2}, {0x0627, 0xFE8D, 1}, {0x0628, 0xFE8F, 2}, {0x0629, 0xFE93, 1},
  {0x062A, 0xFE95, 2}, {0x062B, 0xFE99, 2}, {0x062C, 0xFE9D, 2}, {0x062D, 0xFEA1, 2}, {0x062E, 0xFEA5, 2},
  {0x062F, 0xFEA9, 1}, {0x0630, 0xFEAB, 1}, {0x0631, 0xFEAD, 1}, {0x0632, 0xFEAF, 1},
  {0x0633, 0xFEB1, 2}, {0x0634, 0xFEB5, 2}, {0x0635, 0xFEB9, 2}, {0x0636, 0xFEBD, 2},
  {0x0637, 0xFEC1, 2}, {0x0638, 0xFEC5, 2}, {0x0639, 0xFEC9, 2}, {0x063A, 0xFECD, 2},
  {0x0641, 0xFED1, 2}, {0x0642, 0xFED5, 2}, {0x0643, 0xFED9, 2}, {0x0644, 0xFEDD, 2},
  {0x0645, 0xFEE1, 2}, {0x0646, 0xFEE5, 2}, {0x0647, 0xFEE9, 2},
  {0x0648, 0xFEED, 1}, {0x0649, 0xFEEF, 1}, {0x064A, 0xFEF1, 2}
};

static const ArForm* arFind(unsigned c) {
  for (unsigned i = 0; i < sizeof(AR) / sizeof(AR[0]); i++)
    if (AR[i].base == c) return &AR[i];
  return NULL;
}
static bool isArMark(unsigned c) { return c >= 0x064B && c <= 0x0652; }
static bool isArChar(unsigned c) {
  return (c >= 0x0621 && c <= 0x064A) || c == 0x0640 || c == 0x060C || c == 0x061F || c == 0x061B || isArMark(c);
}

struct ArUnit { unsigned cp; unsigned iso; int kind; };  // kind 3 = tatweel (joins both sides)

static int shapeRun(const unsigned* in, int n, unsigned* out) {
  ArUnit u[300];
  int m = 0;
  for (int i = 0; i < n && m < 299; i++) {
    unsigned c = in[i];
    if (isArMark(c)) continue;
    if (c == 0x0644 && i + 1 < n) {
      unsigned a = in[i + 1], lig = 0;
      if (a == 0x0622) lig = 0xFEF5;
      else if (a == 0x0623) lig = 0xFEF7;
      else if (a == 0x0625) lig = 0xFEF9;
      else if (a == 0x0627) lig = 0xFEFB;
      if (lig) { u[m].cp = lig; u[m].iso = lig; u[m].kind = 1; m++; i++; continue; }
    }
    const ArForm* f = arFind(c);
    if (f) { u[m].cp = c; u[m].iso = f->iso; u[m].kind = f->kind; }
    else if (c == 0x0640) { u[m].cp = c; u[m].iso = c; u[m].kind = 3; }
    else { u[m].cp = c; u[m].iso = c; u[m].kind = -1; }
    m++;
  }
  for (int i = 0; i < m; i++) {
    int k = u[i].kind;
    if (k < 0 || k == 0 || k == 3) { out[i] = u[i].cp; continue; }
    bool jp = i > 0 && (u[i - 1].kind == 2 || u[i - 1].kind == 3);
    bool jn = i + 1 < m && (u[i + 1].kind == 1 || u[i + 1].kind == 2 || u[i + 1].kind == 3);
    unsigned iso = u[i].iso;
    if (k == 1) out[i] = jp ? iso + 1 : iso;
    else out[i] = (jp && jn) ? iso + 3 : (jp ? iso + 1 : (jn ? iso + 2 : iso));
  }
  return m;
}

// ------------------------------------------------------- bidi (simplified UBA)
static bool isNeutralCp(unsigned c) {
  if (c < 0x80) return !((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'));
  return (c >= 0xA0 && c <= 0xBF) || (c >= 0x2000 && c <= 0x206F) || (c >= 0x2190 && c <= 0x21FF) ||
         (c >= 0x25A0 && c <= 0x25FF) || (c >= 0x2700 && c <= 0x27BF);
}

// Produces code points in left-to-right drawing order. Text without Arabic is returned unchanged.
static int visualize(const char* s, unsigned* out, int mx) {
  unsigned cp[300];
  int n = toCps(s, cp, 300);
  bool any = false;
  for (int i = 0; i < n; i++) if (isArChar(cp[i])) { any = true; break; }
  if (!any) {
    int k = n < mx ? n : mx;
    for (int i = 0; i < k; i++) out[i] = cp[i];
    return k;
  }
  char t[300];      // A arabic, D digit, L other strong, N neutral
  char infl[300];   // what a digit counts as when resolving neutrals: 'R' or 'L'
  for (int i = 0; i < n; i++) {
    if (isArChar(cp[i])) t[i] = 'A';
    else if (cp[i] >= '0' && cp[i] <= '9') t[i] = 'D';
    else if (isNeutralCp(cp[i])) t[i] = 'N';
    else t[i] = 'L';
    infl[i] = 'R';
  }
  // a single . , : / + - between two digits belongs to the number
  for (int i = 1; i + 1 < n; i++)
    if (t[i] == 'N' && t[i - 1] == 'D' && t[i + 1] == 'D' &&
        (cp[i] == '.' || cp[i] == ',' || cp[i] == ':' || cp[i] == '/' || cp[i] == '+' || cp[i] == '-')) t[i] = 'D';
  char last = 'S';
  for (int i = 0; i < n; i++) {
    if (t[i] == 'A') last = 'A';
    else if (t[i] == 'L') last = 'L';
    else if (t[i] == 'D') infl[i] = (last == 'L') ? 'L' : 'R';
  }
  char cls[300];    // final display direction: 'R' or 'L'
  for (int i = 0; i < n; i++) cls[i] = (t[i] == 'A') ? 'R' : ((t[i] == 'N') ? '?' : 'L');
  for (int i = 0; i < n;) {
    if (t[i] != 'N') { i++; continue; }
    int j = i;
    while (j < n && t[j] == 'N') j++;
    char lft = 'R', rgt = 'R';
    if (i > 0) lft = (t[i - 1] == 'A') ? 'R' : (t[i - 1] == 'L' ? 'L' : infl[i - 1]);
    if (j < n) rgt = (t[j] == 'A') ? 'R' : (t[j] == 'L' ? 'L' : infl[j]);
    char c = (lft == 'L' && rgt == 'L') ? 'L' : 'R';
    for (int k = i; k < j; k++) cls[k] = c;
    i = j;
  }
  int rs[300], re[300], rn = 0;
  for (int i = 0; i < n;) {
    int j = i;
    while (j < n && cls[j] == cls[i]) j++;
    rs[rn] = i; re[rn] = j; rn++;
    i = j;
  }
  int o = 0;
  for (int r = rn - 1; r >= 0 && o < mx - 2; r--) {
    int a = rs[r], b = re[r];
    if (cls[a] == 'R') {
      unsigned sh[300];
      int m = shapeRun(cp + a, b - a, sh);
      for (int i = m - 1; i >= 0 && o < mx - 1; i--) out[o++] = sh[i];
    } else {
      for (int i = a; i < b && o < mx - 1; i++) out[o++] = cp[i];
    }
  }
  return o;
}

static bool hasAr(const char* s) {
  while (*s) { unsigned c = u8next(&s); if (isArChar(c)) return true; }
  return false;
}

// ---------------------------------------------------------- PKG header
struct PkgInfo { bool ok; char cid[40]; char tid[16]; char reg[8]; unsigned ctype; };

static bool readPkgInfo(const char* path, PkgInfo* pi) {
  memset(pi, 0, sizeof(*pi));
  FILE* f = fopen(path, "rb");
  if (!f) return false;
  unsigned char h[0x80];
  size_t g = fread(h, 1, sizeof(h), f);
  fclose(f);
  if (g < sizeof(h)) return false;
  if (h[0] != 0x7F || h[1] != 'C' || h[2] != 'N' || h[3] != 'T') return false;
  memcpy(pi->cid, h + 0x40, 36);
  pi->cid[36] = 0;
  for (int i = 0; pi->cid[i]; i++)
    if ((unsigned char)pi->cid[i] < 0x20 || (unsigned char)pi->cid[i] > 0x7E) { pi->cid[i] = 0; break; }
  pi->ctype = ((unsigned)h[0x74] << 24) | ((unsigned)h[0x75] << 16) | ((unsigned)h[0x76] << 8) | (unsigned)h[0x77];
  if (strlen(pi->cid) >= 16) {
    memcpy(pi->tid, pi->cid + 7, 9);
    pi->tid[9] = 0;
    memcpy(pi->reg, pi->cid, 2);
    pi->reg[2] = 0;
  }
  pi->ok = true;
  return true;
}

// ---------------------------------------------------------- part names
static bool partInfo(const char* n, char* base, size_t bn, int* idx) {
  int len = (int)strlen(n);
  int i = len - 1;
  while (i >= 0 && n[i] >= '0' && n[i] <= '9') i--;
  if (i == len - 1 || i < 5) return false;
  if (strncmp(n + i - 4, ".part", 5) != 0) return false;
  *idx = atoi(n + i + 1);
  int bl = i - 4;
  if (bl <= 0 || bl >= (int)bn) return false;
  memcpy(base, n, bl);
  base[bl] = 0;
  return true;
}

// name.partN  or  name.NNN (7z / HJSplit style). width = number of digits for the .NNN style.
static bool partParse(const char* n, char* base, size_t bn, int* idx, int* style, int* width) {
  if (partInfo(n, base, bn, idx)) { *style = 0; *width = 0; return true; }
  int len = (int)strlen(n);
  int i = len - 1;
  while (i >= 0 && n[i] >= '0' && n[i] <= '9') i--;
  int digits = len - 1 - i;
  if (digits >= 1 && digits <= 4 && i >= 1 && n[i] == '.' && i < (int)bn) {
    memcpy(base, n, i);
    base[i] = 0;
    *idx = atoi(n + i + 1);
    *style = 1;
    *width = digits;
    return true;
  }
  return false;
}

// game.pkg -> game_merged.pkg
static void altName(char* o, size_t n, const char* base) {
  const char* dot = strrchr(base, '.');
  if (dot && dot != base) snprintf(o, n, "%.*s_merged%s", (int)(dot - base), base, dot);
  else snprintf(o, n, "%s_merged", base);
}

// ------------------------------------------------------------------ state
static Scene2D* sc = NULL;
static int frameID = 0;
static FILE* lg = NULL;
static bool haveFont = false;
#if UI_FT
static FT_Face fBig, fMid, fSm;
#endif

struct Ent { char name[160]; long long size; int kind; int parts; int missing; int grp; int idx; };
// kind: 0 = parent folder, 1 = folder, 2 = file, 4 = one part of a split file (the whole set is found automatically)
struct Grp { char base[160]; int style, width, first, count, last, missing; long long total; };
static Grp grps[64];
static int ngrp = 0;
static bool showUsb = false;
static char usbLines[12][120];
static int usbN = 0;
static Ent ents[MAXF];
static int cnt = 0, sel = 0, scroll = 0;
static char curPath[300] = "/data";
static int mode = 0;  // 0 browse, 1 working, 2 finished
static int parts = 2, minParts = 2, workKind = 0;
static int padOk = 0, padH = -1;
static uint32_t prevB = 0;
static char dbgNote[160] = "", padMsg[160] = "";
static PkgInfo selPkg;
static bool selPkgOk = false;
static char curName[200] = "", sPart[96] = "", sSpeed[64] = "", sEta[64] = "", sMsg[240] = "";
static int sPct = 0, sOK = 1;
static long long gTotal = 1, gDone = 0, gLastB = 0;
static time_t gLastT = 0;

static const Color cBG = {19, 19, 26};
static const Color cCARD = {27, 27, 37};
static const Color cSEL = {52, 36, 110};
static const Color cHDR = {13, 13, 18};
static const Color cPUR = {124, 77, 255};
static const Color cPURL = {158, 134, 255};
static const Color cWHITE = {235, 238, 250};
static const Color cGREY = {140, 146, 170};
static const Color cGREEN = {70, 210, 130};
static const Color cRED = {235, 80, 80};
static const Color cBAR = {42, 42, 58};
static const Color cBLUE = {80, 160, 255};

static const char* S(const char* ar, const char* en) { return haveFont ? ar : en; }

// ------------------------------------------------- pixel font (fallback)
static const char* CH = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.-_/:%?! ";
static const unsigned char GL[][7] = {
 {0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110},
 {0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110},
 {0b01110,0b10001,0b00001,0b00010,0b00100,0b01000,0b11111},
 {0b11110,0b00001,0b00001,0b01110,0b00001,0b00001,0b11110},
 {0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010},
 {0b11111,0b10000,0b11110,0b00001,0b00001,0b10001,0b01110},
 {0b00110,0b01000,0b10000,0b11110,0b10001,0b10001,0b01110},
 {0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000},
 {0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110},
 {0b01110,0b10001,0b10001,0b01111,0b00001,0b00010,0b01100},
 {0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001},
 {0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110},
 {0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110},
 {0b11110,0b10001,0b10001,0b10001,0b10001,0b10001,0b11110},
 {0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111},
 {0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000},
 {0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01111},
 {0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001},
 {0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110},
 {0b00111,0b00010,0b00010,0b00010,0b00010,0b10010,0b01100},
 {0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001},
 {0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111},
 {0b10001,0b11011,0b10101,0b10101,0b10001,0b10001,0b10001},
 {0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001},
 {0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110},
 {0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000},
 {0b01110,0b10001,0b10001,0b10001,0b10101,0b10010,0b01101},
 {0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001},
 {0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110},
 {0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100},
 {0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110},
 {0b10001,0b10001,0b10001,0b10001,0b10001,0b01010,0b00100},
 {0b10001,0b10001,0b10001,0b10101,0b10101,0b10101,0b01010},
 {0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001},
 {0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100},
 {0b11111,0b00001,0b00010,0b00100,0b01000,0b10000,0b11111},
 {0,0,0,0,0,0b01100,0b01100},
 {0,0,0,0b11111,0,0,0},
 {0,0,0,0,0,0,0b11111},
 {0b00001,0b00001,0b00010,0b00100,0b01000,0b10000,0b10000},
 {0,0b01100,0b01100,0,0b01100,0b01100,0},
 {0b11001,0b11010,0b00010,0b00100,0b01000,0b01011,0b10011},
 {0b01110,0b10001,0b00001,0b00010,0b00100,0,0b00100},
 {0b00100,0b00100,0b00100,0b00100,0b00100,0,0b00100},
 {0,0,0,0,0,0,0}
};



static void glyph(int x, int y, int s, char c, Color col) {
  if (c >= 'a' && c <= 'z') c -= 32;
  const char* p = c ? strchr(CH, c) : NULL;
  int i = p ? (int)(p - CH) : 42;
  for (int r = 0; r < 7; r++)
    for (int k = 0; k < 5; k++)
      if (GL[i][r] & (1 << (4 - k))) sc->DrawRectangle(x + k * s, y + r * s, s, s, col);
}

// ------------------------------------------------ text (FreeType + shaping)
#if UI_FT
static FT_Face faceFor(int size) { return size >= 50 ? fBig : (size >= 34 ? fMid : fSm); }

static int gAdv(FT_Face f, unsigned c, int size) {
  if (FT_Load_Char(f, c, 0)) return size / 2;
  return (int)(f->glyph->advance.x >> 6);
}

static int gDraw(FT_Face f, unsigned c, int x, int base, int size, Color fg, Color bg) {
  if (FT_Load_Char(f, c, FT_LOAD_RENDER)) return size / 2;
  FT_GlyphSlot g = f->glyph;
  int adv = (int)(g->advance.x >> 6);
  int bw = (int)g->bitmap.width, bh = (int)g->bitmap.rows, pitch = (int)g->bitmap.pitch;
  const unsigned char* buf = g->bitmap.buffer;
  if (!buf || bw <= 0 || bh <= 0 || g->bitmap.pixel_mode != FT_PIXEL_MODE_GRAY) return adv;
  for (int r = 0; r < bh; r++) {
    int py = base - (int)g->bitmap_top + r;
    if (py < 0 || py >= FH) continue;
    for (int k = 0; k < bw; k++) {
      int a = buf[r * pitch + k];
      if (a < 10) continue;
      int px = x + (int)g->bitmap_left + k;
      if (px < 0 || px >= FW) continue;
      Color c2;
      c2.r = (uint8_t)(bg.r + ((int)fg.r - (int)bg.r) * a / 255);
      c2.g = (uint8_t)(bg.g + ((int)fg.g - (int)bg.g) * a / 255);
      c2.b = (uint8_t)(bg.b + ((int)fg.b - (int)bg.b) * a / 255);
      sc->DrawPixel(px, py, c2);
    }
  }
  return adv;
}
#endif

static int textW(const char* s, int size) {
#if UI_FT
  if (haveFont) {
    unsigned v[320];
    int n = visualize(s, v, 320);
    FT_Face f = faceFor(size);
    int w = 0;
    for (int i = 0; i < n; i++) w += gAdv(f, v[i], size);
    return w;
  }
#endif
  int sc2 = size >= 50 ? 8 : (size >= 34 ? 5 : 4);
  return (int)strlen(s) * 6 * sc2;
}

// y = top of the text line. align: 0 left at x, 1 right edge of [x, x+boxW], 2 centered in the box
static void txt(const char* s, int x, int y, int size, Color fg, Color bg, int boxW = 0, int align = 0) {
  if (!sc || !s || !s[0]) return;
  int px = x;
  if (align != 0 && boxW > 0) {
    int w = textW(s, size);
    px = align == 1 ? x + boxW - w : x + (boxW - w) / 2;
  }
#if UI_FT
  if (haveFont) {
    unsigned v[320];
    int n = visualize(s, v, 320);
    FT_Face f = faceFor(size);
    int base = y + size * 9 / 10;
    for (int i = 0; i < n; i++) px += gDraw(f, v[i], px, base, size, fg, bg);
    return;
  }
#endif
  int sz = size >= 50 ? 8 : (size >= 34 ? 5 : 4);
  for (; *s; s++) { glyph(px, y, sz, *s, fg); px += 6 * sz; }
}

static void fitPx(char* o, size_t n, const char* s, int maxPx, int size) {
  snprintf(o, n, "%s", s);
  int maxCh = maxPx * 10 / (size * 5);
  if ((int)strlen(o) > maxCh + 8) o[maxCh + 8] = 0;
  if (textW(o, size) <= maxPx) return;
  int len = (int)strlen(o);
  int dots = textW("..", size);
  while (len > 3 && textW(o, size) + dots > maxPx) {
    len--;
    while (len > 0 && (((unsigned char)o[len]) & 0xC0) == 0x80) len--;
    o[len] = 0;
  }
  strcat(o, "..");
}

static void fmtSize(char* o, size_t n, long long b) {
  if (b >= 1073741824LL) snprintf(o, n, "%.2f GB", (double)b / 1073741824.0);
  else snprintf(o, n, "%.1f MB", (double)b / 1048576.0);
}

static void rect(int x, int y, int w, int h, Color c) { sc->DrawRectangle(x, y, w, h, c); }

static void barDraw(int x, int y, int w, int h, int pct, Color fill) {
  rect(x, y, w, h, cBAR);
  int fw = w * pct / 100;
  if (fw > 0) rect(x, y, fw, h, fill);
}

// ---------------------------------------------------------------- screens
static void drawHeader() {
  rect(0, 0, FW, 120, cHDR);
  rect(0, 116, FW, 4, cPUR);
  txt("PKG Tool Pro", 70, 26, 56, cWHITE, cHDR);
  txt(S("أداة حزم PS4", "PS4 package tool"), 1000, 40, 38, cPURL, cHDR, 850, 1);
}

static void drawPathBar() {
  rect(70, 132, 1780, 56, cCARD);
  char p[96];
  fitPx(p, sizeof(p), curPath, 1300, 28);
  txt(p, 90, 144, 28, cWHITE, cCARD);
  char c[64];
  snprintf(c, sizeof(c), S("%d عنصر", "%d items"), cnt > 0 && ents[0].kind == 0 ? cnt - 1 : cnt);
  txt(c, 1400, 144, 28, cGREY, cCARD, 430, 1);
}

static void kindText(const Ent& e, char* o, size_t n) {
  if (e.kind == 0 || e.kind == 1) snprintf(o, n, "%s", S("مجلد", "Folder"));
  else if (e.kind == 4) snprintf(o, n, S("جزء %d", "Part %d"), e.idx);
  else { fmtSize(o, n, e.size); }
}

static void drawList() {
  rect(70, 205, 1000, 745, cCARD);
  if (cnt == 0) {
    txt(S("لا توجد ملفات", "No files"), 100, 250, 38, cGREY, cCARD);
    txt(S("ضع ملفات PKG في هذا المجلد", "Put PKG files in this folder"), 100, 320, 28, cGREY, cCARD);
    txt(dbgNote, 100, 380, 28, cPURL, cCARD);
    return;
  }
  for (int r = 0; r < 9; r++) {
    int i = scroll + r;
    if (i >= cnt) break;
    int y = 215 + r * 80;
    bool s = (i == sel);
    Color bg = s ? cSEL : cCARD;
    rect(80, y, 980, 72, bg);
    Color ic = ents[i].kind <= 1 ? cPUR : (ents[i].kind == 4 ? cGREEN : cBLUE);
    rect(80, y, 10, 72, s ? cPURL : ic);
    char nm[200];
    if (ents[i].kind == 0) snprintf(nm, sizeof(nm), "..");
    else fitPx(nm, sizeof(nm), ents[i].name, 640, 34);
    txt(nm, 112, y + 16, 34, s ? cWHITE : cGREY, bg);
    char z[40];
    kindText(ents[i], z, sizeof(z));
    txt(z, 790, y + 22, 28, cPURL, bg, 250, 1);
  }
  if (cnt > 9) {
    int bh = 745 * 9 / cnt;
    if (bh < 30) bh = 30;
    int by = 205 + (745 - bh) * scroll / (cnt - 9);
    rect(1060, by, 6, bh, cBAR);
  }
}

static void drawPkgLines(int y) {
  if (!selPkgOk) {
    txt(S("ليس ملف PKG للـ PS4", "Not a PS4 PKG"), 1130, y, 28, cGREY, cCARD, 700, 1);
    return;
  }
  txt(S("ملف PKG صالح", "Valid PS4 PKG"), 1130, y, 28, cGREEN, cCARD, 700, 1);
  char l[120];
  snprintf(l, sizeof(l), "Content ID: %s", selPkg.cid);
  char f[120];
  fitPx(f, sizeof(f), l, 700, 28);
  txt(f, 1130, y + 40, 28, cWHITE, cCARD, 700, 1);
  snprintf(l, sizeof(l), "Title ID: %s    %s    0x%X", selPkg.tid, selPkg.reg, selPkg.ctype);
  txt(l, 1130, y + 80, 28, cGREY, cCARD, 700, 1);
}

static void drawBrowse() {
  if (cnt == 0) return;
  const Ent& e = ents[sel];
  char nm[200], z[48], l[160];
  if (e.kind == 0) {
    txt(S("الرجوع", "Back"), 1130, 240, 28, cGREY, cCARD, 700, 1);
    txt(S("المجلد الأعلى", "Parent folder"), 1130, 290, 38, cWHITE, cCARD, 700, 1);
    txt(S("اضغط X للعودة", "Press X to go back"), 1130, 400, 28, cPURL, cCARD, 700, 1);
    return;
  }
  fitPx(nm, sizeof(nm), e.name, 700, 38);
  if (e.kind == 1) {
    txt(S("مجلد", "Folder"), 1130, 240, 28, cGREY, cCARD, 700, 1);
    txt(nm, 1130, 290, 38, cWHITE, cCARD, 700, 1);
    txt(S("اضغط X للدخول", "Press X to open"), 1130, 400, 28, cPURL, cCARD, 700, 1);
    return;
  }
  if (e.kind == 2) txt(S("ملف", "File"), 1130, 240, 28, cGREY, cCARD, 700, 1);
  else txt(S("جزء من ملف مقسوم", "Part of a split file"), 1130, 240, 28, cGREY, cCARD, 700, 1);
  txt(nm, 1130, 290, 38, cWHITE, cCARD, 700, 1);
  if (e.kind == 2) {
    fmtSize(z, sizeof(z), e.size);
    txt(z, 1130, 350, 38, cPURL, cCARD, 700, 1);
    drawPkgLines(420);
    txt(S("عدد الأجزاء", "Parts"), 1130, 570, 28, cGREY, cCARD, 700, 1);
    snprintf(l, sizeof(l), "< %d >", parts);
    txt(l, 1130, 610, 56, cWHITE, cCARD, 700, 1);
    char e2[32];
    fmtSize(e2, sizeof(e2), (e.size + parts - 1) / parts);
    snprintf(l, sizeof(l), S("حجم كل جزء تقريباً %s", "Each part about %s"), e2);
    txt(l, 1130, 700, 28, cGREY, cCARD, 700, 1);
    rect(1130, 810, 700, 80, cPUR);
    txt(padOk ? S("اضغط X للتقسيم", "Press X to split") : S("لا يوجد ذراع", "No controller"), 1130, 830, 38, cWHITE, cPUR, 700, 2);
    return;
  }
  const Grp& g = grps[e.grp];
  snprintf(l, sizeof(l), S("هذا الجزء رقم %d من %d", "This is part %d of %d"), e.idx, g.last);
  txt(l, 1130, 350, 34, cPURL, cCARD, 700, 1);
  fmtSize(z, sizeof(z), g.total);
  snprintf(l, sizeof(l), S("الحجم الكلي بعد الدمج: %s", "Size after merge: %s"), z);
  txt(l, 1130, 410, 30, cWHITE, cCARD, 700, 1);
  drawPkgLines(470);
  char o[200];
  fitPx(o, sizeof(o), g.base, 700, 28);
  snprintf(l, sizeof(l), S("الملف الناتج: %s", "Output: %s"), o);
  txt(l, 1130, 640, 28, cGREY, cCARD, 700, 1);
  if (g.missing > 0) {
    snprintf(l, sizeof(l), S("جزء ناقص: رقم %d", "Missing part: %d"), g.missing);
    txt(l, 1130, 700, 38, cRED, cCARD, 700, 1);
    rect(1130, 810, 700, 80, cBAR);
    txt(S("لا يمكن الدمج", "Cannot merge"), 1130, 830, 38, cGREY, cBAR, 700, 2);
  } else {
    txt(S("كل الأجزاء موجودة", "All parts found"), 1130, 700, 38, cGREEN, cCARD, 700, 1);
    rect(1130, 810, 700, 80, cPUR);
    txt(padOk ? S("اضغط X لدمج كل الأجزاء", "Press X to merge all parts") : S("لا يوجد ذراع", "No controller"), 1130, 830, 34, cWHITE, cPUR, 700, 2);
  }
}

static void drawUsb() {
  txt(S("فحص USB", "USB scan"), 1130, 240, 38, cPURL, cCARD, 700, 1);
  for (int i = 0; i < usbN && i < 12; i++) {
    char t[120];
    fitPx(t, sizeof(t), usbLines[i], 700, 28);
    txt(t, 1130, 310 + i * 48, 28, i < 2 ? cWHITE : cGREY, cCARD, 700, 1);
  }
}

static void drawWork() {
  txt(workKind == 0 ? S("جاري التقسيم", "Splitting") : S("جاري الدمج", "Merging"), 1130, 240, 38, cPURL, cCARD, 700, 1);
  char t[200];
  fitPx(t, sizeof(t), curName, 700, 34);
  txt(t, 1130, 300, 34, cWHITE, cCARD, 700, 1);
  txt(sPart, 1130, 360, 28, cGREY, cCARD, 700, 1);
  barDraw(1130, 450, 700, 56, sPct, sOK ? cPUR : cRED);
  char p[16];
  snprintf(p, sizeof(p), "%d%%", sPct);
  txt(p, 1130, 530, 56, cWHITE, cCARD, 700, 1);
  txt(sSpeed, 1130, 630, 28, cGREY, cCARD, 700, 1);
  txt(sEta, 1130, 680, 28, cGREY, cCARD, 700, 1);
  txt(sMsg, 1130, 750, 34, sOK ? (mode == 2 ? cGREEN : cWHITE) : cRED, cCARD, 700, 1);
  if (mode == 2) {
    rect(1130, 840, 700, 70, cPUR);
    txt(S("اضغط X للمتابعة", "Press X to continue"), 1130, 856, 34, cWHITE, cPUR, 700, 2);
  }
}

static void drawFooter() {
  rect(0, 990, FW, 90, cHDR);
  if (padOk) {
    txt(S("تنقل: ↑↓     عدد الأجزاء: ←→     تنفيذ: X     رجوع: O     الأماكن: L1 R1     تحديث: △     USB: □     خروج: Options",
          "Up/Down: browse    Left/Right: parts    X: run    O: back    L1/R1: places    Triangle: refresh    Square: USB    Options: exit"),
        70, 1018, 28, cGREY, cHDR, 1780, 1);
  } else {
    txt(S("الذراع غير متصل - أعيد المحاولة...", "Controller not found - retrying..."), 70, 1000, 28, cRED, cHDR, 1780, 1);
    txt(padMsg, 70, 1040, 24, cGREY, cHDR, 1780, 1);
  }
}

static void render() {
  if (!sc) return;
  sc->FrameBufferFill(cBG);
  drawHeader();
  drawPathBar();
  drawList();
  rect(1110, 205, 740, 745, cCARD);
  if (showUsb) drawUsb(); else if (mode == 0) drawBrowse(); else drawWork();
  drawFooter();
  sc->SubmitFlip(frameID);
  sc->FrameWait(frameID);
  sc->FrameBufferSwap();
  frameID++;
}

// ------------------------------------------------------------- file system
static void LOGF(const char* m) { if (lg) { fprintf(lg, "%s\n", m); fflush(lg); } }

static long long fileSize(const char* path) {
  FILE* f = fopen(path, "rb");
  if (!f) return -1;
  fseeko(f, 0, SEEK_END);
  long long s = ftello(f);
  fclose(f);
  return s;
}

static void pathJoin(char* o, size_t n, const char* dir, const char* name) {
  if (!strcmp(dir, "/")) snprintf(o, n, "/%s", name);
  else snprintf(o, n, "%s/%s", dir, name);
}

#if USE_GD
extern "C" int ui_kopen(const char*, int, int) __asm__("sceKernelOpen");
extern "C" int ui_kclose(int) __asm__("sceKernelClose");
extern "C" int ui_kgetdents(int, char*, int) __asm__("sceKernelGetdents");
static char gbuf[8192] __attribute__((aligned(8)));
#endif

static bool isDirPath(const char* p) {
#if USE_GD
  int fd = ui_kopen(p, 0, 0);
  if (fd < 0) return false;
  int n = ui_kgetdents(fd, gbuf, sizeof(gbuf));
  ui_kclose(fd);
  return n >= 0;
#elif USE_DIR
  DIR* d = opendir(p);
  if (d) { closedir(d); return true; }
  return false;
#else
  (void)p;
  return false;
#endif
}

static char tmpNames[MAXF * 2][160];

static int listNames(const char* path, int mx) {
  int n = 0;
  dbgNote[0] = 0;
#if USE_GD
  int fd = ui_kopen(path, 0, 0);
  if (fd < 0) {
    snprintf(dbgNote, sizeof(dbgNote), "getdents: open failed (%d)", fd);
  } else {
    int total = 0, r = 0, rounds = 0;
    while ((r = ui_kgetdents(fd, gbuf, sizeof(gbuf))) > 0 && rounds < 128) {
      int off = 0;
      while (off + 8 < r) {
        unsigned short reclen = *(const unsigned short*)(gbuf + off + 4);
        unsigned char namlen = *(const unsigned char*)(gbuf + off + 7);
        const char* nm = gbuf + off + 8;
        if (reclen < 8 || off + reclen > r) break;
        if (namlen > 0 && namlen < 150 && nm[namlen] == 0) {
          total++;
          if (n < mx) { snprintf(tmpNames[n], 160, "%.159s", nm); n++; }
        }
        off += reclen;
      }
      rounds++;
    }
    ui_kclose(fd);
    snprintf(dbgNote, sizeof(dbgNote), "getdents: entries=%d", total);
  }
#endif
#if USE_DIR
  if (n == 0) {
    DIR* d = opendir(path);
    if (!d) {
      size_t l = strlen(dbgNote);
      snprintf(dbgNote + l, sizeof(dbgNote) - l, " opendir failed");
    } else {
      struct dirent* e;
      int raw = 0;
      while ((e = readdir(d)) != NULL) {
        raw++;
        if (n < mx) { snprintf(tmpNames[n], 160, "%.159s", e->d_name); n++; }
      }
      closedir(d);
      size_t l = strlen(dbgNote);
      snprintf(dbgNote + l, sizeof(dbgNote) - l, " opendir ok: entries=%d", raw);
    }
  }
#endif
  return n;
}

static int cmpi(const char* a, const char* b) {
  for (;; a++, b++) {
    int x = (unsigned char)*a, y = (unsigned char)*b;
    if (x >= 'A' && x <= 'Z') x += 32;
    if (y >= 'A' && y <= 'Z') y += 32;
    if (x != y) return x - y;
    if (!x) return 0;
  }
}

static int entRank(const Ent& e) { return e.kind == 0 ? 0 : (e.kind == 1 ? 1 : 2); }

static void sortEnts() {
  for (int i = 1; i < cnt; i++)
    for (int j = i; j > 0; j--) {
      int ra = entRank(ents[j - 1]), rb = entRank(ents[j]);
      bool swap = ra > rb || (ra == rb && cmpi(ents[j - 1].name, ents[j].name) > 0);
      if (!swap) break;
      Ent t = ents[j - 1]; ents[j - 1] = ents[j]; ents[j] = t;
    }
}

static bool hasEnt(const char* name, int kind) {
  for (int i = 0; i < cnt; i++) if (ents[i].kind == kind && !strcmp(ents[i].name, name)) return true;
  return false;
}

static void partName(char* o, size_t n, const char* dir, const char* base, int style, int width, int idx) {
  char b[460];
  pathJoin(b, sizeof(b), dir, base);
  if (style == 0) snprintf(o, n, "%s.part%d", b, idx);
  else snprintf(o, n, "%s.%0*d", b, width, idx);
}

// Finds every part of the same split file (same base name and numbering style) and checks for gaps.
static int findGroup(const char* dir, const char* base, int style, int width) {
  for (int i = 0; i < ngrp; i++)
    if (grps[i].style == style && grps[i].width == width && !strcmp(grps[i].base, base)) return i;
  if (ngrp >= 64) return -1;
  Grp& g = grps[ngrp];
  memset(&g, 0, sizeof(g));
  snprintf(g.base, sizeof(g.base), "%s", base);
  g.style = style;
  g.width = width;
  g.first = 1;
  char p[560];
  if (style == 1 && width >= 2) {
    partName(p, sizeof(p), dir, base, style, width, 0);
    if (fileSize(p) >= 0) g.first = 0;
  }
  int found = 0, contiguous = 0, gap = 0, highest = g.first - 1;
  for (int i = g.first; i < g.first + 99; i++) {
    partName(p, sizeof(p), dir, base, style, width, i);
    long long s = fileSize(p);
    if (s < 0) { if (!gap && contiguous == i - g.first) gap = i; continue; }
    found++;
    g.total += s;
    highest = i;
    if (contiguous == i - g.first) contiguous++;
  }
  g.count = contiguous;
  g.last = highest;
  g.missing = (highest >= g.first + contiguous) ? gap : 0;
  if (found == 0) g.missing = g.first;
  g.last = highest - g.first + 1;
  if (g.last < 1) g.last = 1;
  g.count = found;
  return ngrp++;
}

static const char* EX_ROOT[] = {"data", "user", "mnt", "system_data", "system", "app0", "hostapp", "preinst", "preinst2", "update", "usr", NULL};
static const char* EX_MNT[] = {"usb0", "usb1", "usb2", "usb3", "usb4", "usb5", "usb6", "usb7", "ext0", "ext1", "hdd0", "sandbox", NULL};
static const char* EX_USER[] = {"home", "data", "system", "av_contents", "download0", NULL};

// Some folders are hidden from directory listings on the console; probe the well-known ones directly.
static void addExtras(const char** names) {
  for (int k = 0; names[k] && cnt < MAXF; k++) {
    if (hasEnt(names[k], 1)) continue;
    char full[460];
    pathJoin(full, sizeof(full), curPath, names[k]);
    if (!isDirPath(full)) continue;
    Ent& e = ents[cnt];
    memset(&e, 0, sizeof(e));
    snprintf(e.name, sizeof(e.name), "%s", names[k]);
    e.kind = 1;
    cnt++;
  }
}

static void scanDir() {
  cnt = 0; sel = 0; scroll = 0; ngrp = 0;
  if (strcmp(curPath, "/") != 0) {
    memset(&ents[0], 0, sizeof(Ent));
    snprintf(ents[0].name, sizeof(ents[0].name), "..");
    ents[0].kind = 0;
    cnt = 1;
  }
  int n = listNames(curPath, MAXF * 2);
  for (int i = 0; i < n && cnt < MAXF; i++) {
    const char* nm = tmpNames[i];
    if (nm[0] == '.' || strlen(nm) > 150) continue;
    char full[460];
    pathJoin(full, sizeof(full), curPath, nm);
    Ent& e = ents[cnt];
    memset(&e, 0, sizeof(e));
    if (isDirPath(full)) {
      snprintf(e.name, sizeof(e.name), "%s", nm);
      e.kind = 1;
      cnt++;
      continue;
    }
    long long s = fileSize(full);
    if (s < 0 || s > 20000000000000LL) continue;
    snprintf(e.name, sizeof(e.name), "%s", nm);
    e.size = s;
    e.kind = 2;
    char base[160];
    int idx = 0, style = 0, width = 0;
    if (partParse(nm, base, sizeof(base), &idx, &style, &width)) {
      int g = findGroup(curPath, base, style, width);
      if (g >= 0 && (style == 0 || grps[g].count >= 2)) {
        e.kind = 4;
        e.grp = g;
        e.idx = idx;
      }
    }
    cnt++;
  }
  if (!strcmp(curPath, "/")) addExtras(EX_ROOT);
  else if (!strcmp(curPath, "/mnt")) addExtras(EX_MNT);
  else if (!strcmp(curPath, "/user")) addExtras(EX_USER);
  sortEnts();
  char m[520];
  snprintf(m, sizeof(m), "scan %s: %d entries (%s)", curPath, cnt, dbgNote);
  LOGF(m);
}

static void onSelect() {
  selPkgOk = false;
  if (cnt == 0) return;
  const Ent& e = ents[sel];
  char full[560];
  if (e.kind == 2) {
    pathJoin(full, sizeof(full), curPath, e.name);
    selPkgOk = readPkgInfo(full, &selPkg);
    int need = (int)((e.size + 3999999999LL) / 4000000000LL);
    if (need < 2) need = 2;
    minParts = need;
    if (parts < need) parts = need;
    if (parts > need + 8) parts = need;
  } else if (e.kind == 4) {
    const Grp& g = grps[e.grp];
    partName(full, sizeof(full), curPath, g.base, g.style, g.width, g.first);
    selPkgOk = readPkgInfo(full, &selPkg);
  }
}

// ------------------------------------------------------------ split / merge
static void fail(const char* m) { sOK = 0; snprintf(sMsg, sizeof(sMsg), "%s", m); LOGF(m); }

static void progress(long long add) {
  gDone += add;
  int p = (int)(gDone * 100 / gTotal);
  time_t n = time(NULL);
  bool upd = false;
  if (n - gLastT >= 1) {
    long long mb = (gDone - gLastB) / 1048576 / (long long)(n - gLastT);
    snprintf(sSpeed, sizeof(sSpeed), S("السرعة: %lld MB/s", "Speed: %lld MB/s"), mb);
    long long left = mb > 0 ? (gTotal - gDone) / 1048576 / mb : 0;
    snprintf(sEta, sizeof(sEta), S("باقي %lld دقيقة %lld ثانية", "%lld min %lld s left"), left / 60, left % 60);
    gLastT = n;
    gLastB = gDone;
    upd = true;
  }
  if (p != sPct) { sPct = p; upd = true; }
  if (upd) render();
}

static size_t gBufSz = BUFSZ;

static char* allocBuf() {
  size_t sizes[4] = {32u << 20, 16u << 20, 8u << 20, 4u << 20};
  for (int i = 0; i < 4; i++) {
    char* b = (char*)malloc(sizes[i]);
    if (b) { gBufSz = sizes[i]; return b; }
  }
  return NULL;
}

static FILE* openRead(const char* p) {
  FILE* f = fopen(p, "rb");
  if (f) setvbuf(f, NULL, _IONBF, 0);
  return f;
}

static FILE* openWrite(const char* p) {
  FILE* f = fopen(p, "wb");
  if (f) setvbuf(f, NULL, _IONBF, 0);
  return f;
}

static int copyn(FILE* s, FILE* d, long long len, char* buf) {
  while (len > 0) {
    size_t want = len < (long long)gBufSz ? (size_t)len : gBufSz;
    size_t g = fread(buf, 1, want, s);
    if (g == 0) return -1;
    if (fwrite(buf, 1, g, d) != g) return -2;
    len -= g;
    progress((long long)g);
  }
  return 0;
}

static void resetWork(const char* name, int kind) {
  snprintf(curName, sizeof(curName), "%s", name);
  workKind = kind;
  sOK = 1; sPct = 0; sSpeed[0] = 0; sEta[0] = 0; sMsg[0] = 0; sPart[0] = 0;
}

static int doSplit(const char* in, const char* shown, int n) {
  char out[560];
  resetWork(shown, 0);
  snprintf(out, sizeof(out), "%s.part1", in);
  if (fileSize(out) >= 0) { fail(S("الأجزاء موجودة مسبقاً - احذفها أولاً", "Parts already exist - delete them first")); return -1; }
  FILE* f = openRead(in);
  if (!f) { fail(S("تعذر فتح الملف", "Cannot open input file")); return -1; }
  fseeko(f, 0, SEEK_END);
  long long size = ftello(f);
  fseeko(f, 0, SEEK_SET);
  if (n < 2 || n > size) { fail(S("عدد الأجزاء غير صالح", "Bad parts count")); fclose(f); return -1; }
  long long ps = (size + n - 1) / n;
  if (ps >= MAXPART) { fail(S("الجزء أكبر من 4GB - زد عدد الأجزاء", "Part over 4GB - use more parts")); fclose(f); return -1; }
  char* buf = allocBuf();
  if (!buf) { fail(S("الذاكرة غير كافية", "Out of memory")); fclose(f); return -1; }
  gTotal = size > 0 ? size : 1; gDone = 0; gLastB = 0; gLastT = time(NULL);
  render();
  long long done = 0, written = 0;
  for (int i = 1; i <= n; i++) {
    long long len = ps < size - done ? ps : size - done;
    if (len <= 0) break;
    snprintf(sPart, sizeof(sPart), S("الجزء %d من %d", "Part %d of %d"), i, n);
    snprintf(out, sizeof(out), "%s.part%d", in, i);
    FILE* o = openWrite(out);
    if (!o) { fail(S("تعذر كتابة الجزء", "Cannot write part")); free(buf); fclose(f); return -2; }
    int r = copyn(f, o, len, buf);
    fclose(o);
    if (r) { fail(S("فشل النسخ - ربما الذاكرة ممتلئة", "Copy failed - disk full?")); free(buf); fclose(f); return -3; }
    long long ws = fileSize(out);
    if (ws != len) { fail(S("حجم الجزء غير صحيح", "Part size mismatch")); free(buf); fclose(f); return -4; }
    written += ws;
    done += len;
  }
  free(buf);
  fclose(f);
  if (written != size) { fail(S("مجموع الأجزاء لا يطابق الأصل", "Parts total does not match")); return -5; }
  sPct = 100;
  snprintf(sMsg, sizeof(sMsg), S("تم التقسيم - %d أجزاء", "Done - %d parts"), n);
  LOGF(sMsg);
  render();
  return 0;
}

static int doMerge(const char* dir, int gi) {
  char pn[560], outp[560];
  const Grp& g = grps[gi];
  resetWork(g.base, 1);
  if (g.missing > 0) {
    char m[120];
    snprintf(m, sizeof(m), S("جزء ناقص: رقم %d", "Missing part: %d"), g.missing);
    fail(m);
    return -1;
  }
  int cn = g.count;
  long long total = g.total;
  pathJoin(outp, sizeof(outp), dir, g.base);
  if (fileSize(outp) >= 0) {
    if (fileSize(outp) == total) { fail(S("الملف المدموج موجود مسبقاً", "Already merged - output exists")); return -2; }
    char alt[200];
    altName(alt, sizeof(alt), g.base);
    pathJoin(outp, sizeof(outp), dir, alt);
    if (fileSize(outp) >= 0) { fail(S("الملف الناتج موجود - احذفه أو غيّر اسمه", "Output file exists - delete or rename it")); return -2; }
  }
  FILE* o = openWrite(outp);
  if (!o) { fail(S("تعذر كتابة الملف الناتج", "Cannot write output")); return -2; }
  char* buf = allocBuf();
  if (!buf) { fail(S("الذاكرة غير كافية", "Out of memory")); fclose(o); return -2; }
  gTotal = total > 0 ? total : 1; gDone = 0; gLastB = 0; gLastT = time(NULL);
  render();
  int n = 0;
  for (int i = g.first; i < g.first + 99 && n < cn; i++) {
    partName(pn, sizeof(pn), dir, g.base, g.style, g.width, i);
    FILE* f = openRead(pn);
    if (!f) continue;
    n++;
    snprintf(sPart, sizeof(sPart), S("الجزء %d من %d", "Part %d of %d"), n, cn);
    fseeko(f, 0, SEEK_END);
    long long len = ftello(f);
    fseeko(f, 0, SEEK_SET);
    int r = copyn(f, o, len, buf);
    fclose(f);
    if (r) { fail(S("فشل النسخ - ربما الذاكرة ممتلئة", "Copy failed - disk full?")); free(buf); fclose(o); return -4; }
  }
  free(buf);
  fclose(o);
  if (fileSize(outp) != total) { fail(S("حجم الملف النهائي غير صحيح", "Final size mismatch")); return -5; }
  sPct = 100;
  PkgInfo pi;
  if (readPkgInfo(outp, &pi)) snprintf(sMsg, sizeof(sMsg), S("تم الدمج - PKG صالح %s", "Done - valid PKG %s"), pi.tid);
  else snprintf(sMsg, sizeof(sMsg), S("تم الدمج - %d أجزاء", "Done - %d parts merged"), cn);
  LOGF(sMsg);
  render();
  return 0;
}

// -------------------------------------------------------------- controller
#if USE_PAD
extern "C" int ui_usinit(const void*) __asm__("sceUserServiceInitialize");
extern "C" int ui_usgetinit(int*) __asm__("sceUserServiceGetInitialUser");
extern "C" int ui_padinit() __asm__("scePadInit");
extern "C" int ui_padopen(int, int, int, void*) __asm__("scePadOpen");
extern "C" int ui_padread(int, void*) __asm__("scePadReadState");
static char padbuf[512] __attribute__((aligned(16)));
#endif
static bool padInited = false;
static int padUser = 0, rcInit = 0, rcPadInit = 0, rcUser = 0, rcOpen = 0, holdFrames = 0;

static void padTryOpen() {
#if USE_PAD
  if (!padInited) {
    int params[4] = {700, 0, 0, 0};
    rcInit = ui_usinit(params);
    rcPadInit = ui_padinit();
    padInited = true;
  }
  rcUser = ui_usgetinit(&padUser);
  if (rcUser == 0) {
    rcOpen = ui_padopen(padUser, 0, 0, NULL);
    if (rcOpen > 0) { padH = rcOpen; padOk = 1; }
  }
  snprintf(padMsg, sizeof(padMsg), "userinit=%08X padinit=%08X getuser=%08X (id %d) padopen=%08X",
           (unsigned)rcInit, (unsigned)rcPadInit, (unsigned)rcUser, padUser, (unsigned)rcOpen);
  LOGF(padMsg);
#else
  snprintf(padMsg, sizeof(padMsg), "built without controller support");
#endif
}

static uint32_t padPressed() {
#if USE_PAD
  if (!padOk) return 0;
  memset(padbuf, 0, sizeof(padbuf));
  if (ui_padread(padH, padbuf) != 0) return 0;
  uint32_t b = *(const uint32_t*)padbuf;
  uint32_t p = b & ~prevB;
  if (b & (B_UP | B_DOWN)) {
    holdFrames++;
    if (holdFrames > 12 && holdFrames % 3 == 0) p |= (b & (B_UP | B_DOWN));
  } else {
    holdFrames = 0;
  }
  prevB = b;
  return p;
#else
  return 0;
#endif
}

// ---------------------------------------------------------------- navigation
#define NROOT 9
static const char* ROOTS[NROOT] = {"/data/splitter", "/data", "/user", "/mnt/usb0", "/mnt/usb1", "/mnt/ext0", "/mnt", "/system_data", "/"};
static int rootIdx = 0;

static void goRoot(int dir) {
  for (int k = 0; k < NROOT; k++) {
    rootIdx = (rootIdx + dir + NROOT) % NROOT;
    if (isDirPath(ROOTS[rootIdx])) {
      snprintf(curPath, sizeof(curPath), "%s", ROOTS[rootIdx]);
      scanDir();
      onSelect();
      return;
    }
  }
}

static void goUp() {
  if (!strcmp(curPath, "/")) return;
  char* s = strrchr(curPath, '/');
  if (!s) return;
  if (s == curPath) curPath[1] = 0; else *s = 0;
}

static void enterDir(const char* name) {
  char n[300];
  pathJoin(n, sizeof(n), curPath, name);
  snprintf(curPath, sizeof(curPath), "%s", n);
}


// Safe USB probe: only lists device nodes and USB mount points, it does not talk to any device.
static void usbScan() {
  usbN = 0;
  int n = listNames("/dev", 400);
  int found = 0;
  for (int i = 0; i < n && usbN < 8; i++) {
    const char* nm = tmpNames[i];
    if (!strncmp(nm, "ugen", 4) || !strncmp(nm, "usb", 3) || !strncmp(nm, "umass", 5) || (nm[0] == 'd' && nm[1] == 'a' && nm[2] >= '0' && nm[2] <= '9')) {
      snprintf(usbLines[usbN++], 120, "/dev/%s", nm);
      found++;
    }
  }
  for (int k = 0; k < 8 && usbN < 10; k++) {
    char p[40];
    snprintf(p, sizeof(p), "/mnt/usb%d", k);
    if (isDirPath(p)) snprintf(usbLines[usbN++], 120, "%s", S("مشغل USB جاهز: ", "USB storage mounted: ")), strncat(usbLines[usbN - 1], p, 60);
  }
  if (n == 0) snprintf(usbLines[usbN++], 120, "%s", S("تعذر قراءة /dev من داخل التطبيق", "Cannot read /dev from the app"));
  else if (found == 0) snprintf(usbLines[usbN++], 120, "%s", S("لا توجد أجهزة USB ظاهرة", "No USB devices visible"));
  snprintf(usbLines[usbN++], 120, "%s", S("الـ PS4 يفهم فقط وحدات التخزين", "PS4 only mounts USB storage"));
  snprintf(usbLines[usbN++], 120, "%s", S("الهواتف تستعمل MTP أو ADB", "Phones use MTP or ADB instead"));
}

// A job.txt in /data/splitter (3 lines: split|merge, file name, parts) still works without a controller.
static bool runJobFile() {
  FILE* j = fopen("/data/splitter/job.txt", "r");
  if (!j) return false;
  char md[32] = "", nm[256] = "", np[32] = "";
  fgets(md, sizeof(md), j);
  fgets(nm, sizeof(nm), j);
  fgets(np, sizeof(np), j);
  fclose(j);
  md[strcspn(md, "\r\n")] = 0;
  nm[strcspn(nm, "\r\n")] = 0;
  char full[320];
  snprintf(full, sizeof(full), "/data/splitter/%s", nm);
  snprintf(curPath, sizeof(curPath), "/data/splitter");
  mode = 1;
  if (!strcmp(md, "split")) doSplit(full, nm, atoi(np));
  else if (!strcmp(md, "merge")) {
    scanDir();
    int gi = -1;
    for (int i = 0; i < cnt; i++) if (ents[i].kind == 4 && !strcmp(grps[ents[i].grp].base, nm)) { gi = ents[i].grp; break; }
    if (gi >= 0) doMerge(curPath, gi); else { resetWork(nm, 1); fail("job.txt: no parts found"); }
  }
  else { resetWork(nm, 0); fail("job.txt: mode must be split or merge"); }
  mode = 2;
  return true;
}

int main() {
  lg = fopen("/data/splitter/log.txt", "w");
  sc = new Scene2D(FW, FH, 4);
  if (!sc->Init(0xC000000, 2)) {
    LOGF("video init failed");
    sc = NULL;
  }
#if UI_FT
  if (sc) {
    haveFont = sc->InitFont(&fBig, PS4UI_FONT, 56) && sc->InitFont(&fMid, PS4UI_FONT, 38) && sc->InitFont(&fSm, PS4UI_FONT, 28);
    LOGF(haveFont ? "font ok" : "font failed - using pixel font");
  }
#endif
  if (isDirPath("/data/splitter")) snprintf(curPath, sizeof(curPath), "/data/splitter");
  else snprintf(curPath, sizeof(curPath), "/data");
  padTryOpen();
  scanDir();
  onSelect();
  render();
  bool jobTried = false, dirty = true;
  time_t lastR = 0, lastPad = time(NULL);
  for (;;) {
    time_t now = time(NULL);
    if (!padOk && now - lastPad >= 2) { padTryOpen(); lastPad = now; dirty = true; }
    if (!padOk && !jobTried) { jobTried = true; if (runJobFile()) dirty = true; }
    uint32_t p = padPressed();
    if (p & B_OPTIONS) break;
    if (showUsb) {
      if (p & (B_SQUARE | B_CIRCLE | B_CROSS)) { showUsb = false; dirty = true; }
    } else if (mode == 0) {
      if (p & B_SQUARE) { usbScan(); showUsb = true; dirty = true; }
      if (p & B_L1) { goRoot(-1); dirty = true; }
      if (p & B_R1) { goRoot(1); dirty = true; }
      if ((p & B_DOWN) && sel + 1 < cnt) { sel++; if (sel >= scroll + 9) scroll = sel - 8; onSelect(); dirty = true; }
      if ((p & B_UP) && sel > 0) { sel--; if (sel < scroll) scroll = sel; onSelect(); dirty = true; }
      if (cnt > 0 && ents[sel].kind == 2) {
        if (p & B_RIGHT) { if (parts < 99) parts++; dirty = true; }
        if (p & B_LEFT) { if (parts > minParts) parts--; dirty = true; }
      }
      if (p & B_TRI) { scanDir(); onSelect(); dirty = true; }
      if (p & B_CIRCLE) { goUp(); scanDir(); onSelect(); dirty = true; }
      if ((p & B_CROSS) && cnt > 0) {
        Ent e = ents[sel];
        char full[460];
        if (e.kind == 0) { goUp(); scanDir(); onSelect(); }
        else if (e.kind == 1) { enterDir(e.name); scanDir(); onSelect(); }
        else if (e.kind == 2) {
          pathJoin(full, sizeof(full), curPath, e.name);
          mode = 1;
          doSplit(full, e.name, parts);
          mode = 2;
        } else if (e.kind == 4) {
          mode = 1;
          doMerge(curPath, e.grp);
          mode = 2;
        }
        dirty = true;
      }
    } else if (mode == 2) {
      if (p & (B_CROSS | B_CIRCLE)) { mode = 0; scanDir(); onSelect(); dirty = true; }
    }
    if (dirty || now - lastR >= 2) { render(); dirty = false; lastR = now; }
    sceKernelUsleep(30000);
  }
  if (lg) fclose(lg);
  return 0;
}
