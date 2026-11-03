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
#if USE_PAD
#include <orbis/UserService.h>
#include <orbis/Pad.h>
#endif
#if USE_DIR
#include <dirent.h>
#endif
//PRE_END

#ifndef PS4UI_FONT
#define PS4UI_FONT "/app0/Gontserrat-Regular.ttf"
#endif
#define BASE "/data/splitter"
#define BUFSZ (8*1024*1024)
#define MAXPART 4294967295LL
#define FW 1920
#define FH 1080
#define MAXF 96

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

static Scene2D* sc = NULL;
static int frameID = 0;
static FILE* lg = NULL;
static bool haveFont = false;
#ifdef GRAPHICS_USES_FONT
static FT_Face fBig, fMid, fSm;
#endif
static int tab = 0, mode = 0, sel = 0, scroll = 0, cnt = 0, parts = 2, minParts = 2, padOk = 0;
static char names[MAXF][160];
static long long sizes[MAXF];
static int pcount[MAXF];
static char curName[160] = "", sPart[64] = "", sSpeed[64] = "", sEta[64] = "", sMsg[200] = "";
static int sPct = 0, sOK = 1;
static long long gTotal = 1, gDone = 0, gLastB = 0;
static time_t gLastT = 0;
static int dbgRaw = 0;
static char dbgNote[120] = "";
static int padH = -1;
static uint32_t prevB = 0;

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

static void txt(const char* t, int x, int y, int size, Color fg, Color bg) {
#ifdef GRAPHICS_USES_FONT
  if (haveFont) {
    FT_Face f = size >= 50 ? fBig : (size >= 34 ? fMid : fSm);
    sc->DrawText((char*)t, f, x, y + size * 93 / 100, bg, fg);
    return;
  }
#endif
  (void)bg;
  int s = size >= 50 ? 8 : (size >= 34 ? 5 : 4);
  for (; *t; t++) { glyph(x, y, s, *t, fg); x += 6 * s; }
}

static void fit(char* o, size_t n, const char* s, int mx) {
  size_t l = strlen(s);
  if ((int)l <= mx) { snprintf(o, n, "%s", s); return; }
  snprintf(o, n, "%.*s...", mx - 3, s);
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

static void drawList() {
  rect(70, 240, 1000, 700, cCARD);
  if (cnt == 0) {
    txt("No files found", 120, 300, 38, cGREY, cCARD);
    txt(tab == 0 ? "Put PKG files in /data/splitter" : "Put .part1 .part2 files there", 120, 370, 28, cGREY, cCARD);
    txt(dbgNote, 120, 430, 28, cPURL, cCARD);
    return;
  }
  for (int r = 0; r < 9; r++) {
    int i = scroll + r;
    if (i >= cnt) break;
    int y = 250 + r * 76;
    bool s = (i == sel);
    Color bg = s ? cSEL : cCARD;
    rect(80, y, 980, 68, bg);
    if (s) rect(80, y, 8, 68, cPUR);
    char t[48];
    fit(t, sizeof(t), names[i], 28);
    txt(t, 110, y + 12, 38, s ? cWHITE : cGREY, bg);
    char z[32];
    fmtSize(z, sizeof(z), sizes[i]);
    txt(z, 850, y + 18, 28, cPURL, bg);
  }
}

static void drawBrowse() {
  if (cnt == 0) return;
  txt(tab == 0 ? "File to split" : "Merge to file", 1150, 270, 28, cGREY, cCARD);
  char t[48];
  fit(t, sizeof(t), names[sel], 28);
  txt(t, 1150, 320, 38, cWHITE, cCARD);
  char z[32];
  fmtSize(z, sizeof(z), sizes[sel]);
  txt(z, 1150, 390, 38, cPURL, cCARD);
  if (tab == 0) {
    txt("Parts", 1150, 480, 28, cGREY, cCARD);
    char p[32];
    snprintf(p, sizeof(p), "< %d >", parts);
    txt(p, 1150, 520, 56, cWHITE, cCARD);
    char e[32], l[80];
    fmtSize(e, sizeof(e), (sizes[sel] + parts - 1) / parts);
    snprintf(l, sizeof(l), "Each part about %s", e);
    txt(l, 1150, 610, 28, cGREY, cCARD);
  } else {
    char p[48];
    snprintf(p, sizeof(p), "Parts found: %d", pcount[sel]);
    txt(p, 1150, 480, 38, cWHITE, cCARD);
  }
  rect(1150, 780, 660, 80, cPUR);
  txt(padOk ? "Press X to start" : "No controller", 1312, 800, 38, cWHITE, cPUR);
}

static void drawWork() {
  txt(tab == 0 ? "Splitting" : "Merging", 1150, 270, 38, cPURL, cCARD);
  char t[48];
  fit(t, sizeof(t), curName, 28);
  txt(t, 1150, 330, 38, cWHITE, cCARD);
  txt(sPart, 1150, 390, 28, cGREY, cCARD);
  barDraw(1150, 470, 660, 56, sPct, sOK ? cPUR : cRED);
  char p[16];
  snprintf(p, sizeof(p), "%d%%", sPct);
  txt(p, 1150, 550, 56, cWHITE, cCARD);
  txt(sSpeed, 1150, 650, 28, cGREY, cCARD);
  txt(sEta, 1150, 700, 28, cGREY, cCARD);
  txt(sMsg, 1150, 770, 38, sOK ? (mode == 2 ? cGREEN : cWHITE) : cRED, cCARD);
  if (mode == 2) {
    rect(1150, 850, 660, 70, cPUR);
    txt("Press X to continue", 1328, 864, 28, cWHITE, cPUR);
  }
}

static void render() {
  if (!sc) return;
  sc->FrameBufferFill(cBG);
  rect(0, 0, FW, 120, cHDR);
  rect(0, 116, FW, 4, cPUR);
  txt("PKG Tool Pro", 70, 28, 56, cWHITE, cHDR);
  txt(BASE, 1500, 46, 28, cGREY, cHDR);
  Color t0 = tab == 0 ? cPUR : cCARD;
  Color t1 = tab == 1 ? cPUR : cCARD;
  rect(70, 150, 430, 64, t0);
  txt("Split", 230, 162, 38, tab == 0 ? cWHITE : cGREY, t0);
  rect(520, 150, 430, 64, t1);
  txt("Merge", 680, 162, 38, tab == 1 ? cWHITE : cGREY, t1);
  drawList();
  rect(1110, 240, 740, 700, cCARD);
  if (mode == 0) drawBrowse(); else drawWork();
  rect(0, 990, FW, 90, cHDR);
  txt(padOk ? "Up Down: select    Left Right: parts    X: start    L1 R1: tab    Triangle: refresh    Options: exit"
            : "Controller not found - using job.txt", 70, 1020, 28, cGREY, cHDR);
  sc->SubmitFlip(frameID);
  sc->FrameWait(frameID);
  sc->FrameBufferSwap();
  frameID++;
}

static void LOGF(const char* m) { if (lg) { fprintf(lg, "%s\n", m); fflush(lg); } }
static void fail(const char* m) { sOK = 0; snprintf(sMsg, sizeof(sMsg), "%s", m); LOGF(m); }

static void progress(long long add) {
  gDone += add;
  int p = (int)(gDone * 100 / gTotal);
  time_t n = time(NULL);
  bool upd = false;
  if (n - gLastT >= 1) {
    long long mb = (gDone - gLastB) / 1048576 / (long long)(n - gLastT);
    snprintf(sSpeed, sizeof(sSpeed), "Speed: %lld MB/s", mb);
    long long left = mb > 0 ? (gTotal - gDone) / 1048576 / mb : 0;
    snprintf(sEta, sizeof(sEta), "%lld min %lld s left", left / 60, left % 60);
    gLastT = n;
    gLastB = gDone;
    upd = true;
  }
  if (p != sPct) { sPct = p; upd = true; }
  if (upd) render();
}

static int copyn(FILE* s, FILE* d, long long len, char* buf) {
  while (len > 0) {
    size_t want = len < BUFSZ ? (size_t)len : BUFSZ;
    size_t g = fread(buf, 1, want, s);
    if (g == 0) return -1;
    if (fwrite(buf, 1, g, d) != g) return -2;
    len -= g;
    progress((long long)g);
  }
  return 0;
}

static void resetWork(const char* name) {
  snprintf(curName, sizeof(curName), "%s", name);
  sOK = 1; sPct = 0; sSpeed[0] = 0; sEta[0] = 0; sMsg[0] = 0; sPart[0] = 0;
}

static int doSplit(const char* name, int n) {
  char in[512], out[600];
  resetWork(name);
  snprintf(in, sizeof(in), "%s/%s", BASE, name);
  FILE* f = fopen(in, "rb");
  if (!f) { fail("Cannot open input file"); return -1; }
  fseeko(f, 0, SEEK_END);
  long long size = ftello(f);
  fseeko(f, 0, SEEK_SET);
  if (n < 2 || n > size) { fail("Bad parts count"); fclose(f); return -1; }
  long long ps = (size + n - 1) / n;
  if (ps >= MAXPART) { fail("Part over 4GB - use more parts"); fclose(f); return -1; }
  char* buf = (char*)malloc(BUFSZ);
  if (!buf) { fail("Out of memory"); fclose(f); return -1; }
  gTotal = size > 0 ? size : 1; gDone = 0; gLastB = 0; gLastT = time(NULL);
  render();
  long long done = 0;
  for (int i = 1; i <= n; i++) {
    long long len = ps < size - done ? ps : size - done;
    if (len <= 0) break;
    snprintf(sPart, sizeof(sPart), "Part %d of %d", i, n);
    snprintf(out, sizeof(out), "%s.part%d", in, i);
    FILE* o = fopen(out, "wb");
    if (!o) { fail("Cannot write part"); free(buf); fclose(f); return -2; }
    int r = copyn(f, o, len, buf);
    fclose(o);
    if (r) { fail("Copy failed - disk full?"); free(buf); fclose(f); return -3; }
    done += len;
  }
  free(buf);
  fclose(f);
  sPct = 100;
  snprintf(sMsg, sizeof(sMsg), "Done - %d parts", n);
  LOGF(sMsg);
  render();
  return 0;
}

static int doMerge(const char* name) {
  char in[512], pn[600];
  resetWork(name);
  snprintf(in, sizeof(in), "%s/%s", BASE, name);
  int cn = 0;
  long long total = 0;
  for (;;) {
    snprintf(pn, sizeof(pn), "%s.part%d", in, cn + 1);
    FILE* f = fopen(pn, "rb");
    if (!f) break;
    fseeko(f, 0, SEEK_END);
    total += ftello(f);
    fclose(f);
    cn++;
  }
  if (cn == 0) { fail("No parts found"); return -1; }
  FILE* o = fopen(in, "wb");
  if (!o) { fail("Cannot write output"); return -2; }
  char* buf = (char*)malloc(BUFSZ);
  if (!buf) { fail("Out of memory"); fclose(o); return -2; }
  gTotal = total > 0 ? total : 1; gDone = 0; gLastB = 0; gLastT = time(NULL);
  render();
  for (int i = 1; i <= cn; i++) {
    snprintf(sPart, sizeof(sPart), "Part %d of %d", i, cn);
    snprintf(pn, sizeof(pn), "%s.part%d", in, i);
    FILE* f = fopen(pn, "rb");
    if (!f) { fail("Missing part"); free(buf); fclose(o); return -3; }
    fseeko(f, 0, SEEK_END);
    long long len = ftello(f);
    fseeko(f, 0, SEEK_SET);
    int r = copyn(f, o, len, buf);
    fclose(f);
    if (r) { fail("Copy failed - disk full?"); free(buf); fclose(o); return -4; }
  }
  free(buf);
  fclose(o);
  FILE* c = fopen(in, "rb");
  long long fin = -1;
  if (c) { fseeko(c, 0, SEEK_END); fin = ftello(c); fclose(c); }
  if (fin != total) { fail("Final size mismatch"); return -5; }
  sPct = 100;
  snprintf(sMsg, sizeof(sMsg), "Done - %d parts merged", cn);
  LOGF(sMsg);
  render();
  return 0;
}

static long long fileSize(const char* path) {
  FILE* f = fopen(path, "rb");
  if (!f) return -1;
  fseeko(f, 0, SEEK_END);
  long long s = ftello(f);
  fclose(f);
  return s;
}

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

static void sortList() {
  for (int i = 0; i < cnt; i++)
    for (int j = i + 1; j < cnt; j++)
      if (strcmp(names[i], names[j]) > 0) {
        char t[160];
        memcpy(t, names[i], 160);
        memcpy(names[i], names[j], 160);
        memcpy(names[j], t, 160);
        long long s = sizes[i]; sizes[i] = sizes[j]; sizes[j] = s;
        int p = pcount[i]; pcount[i] = pcount[j]; pcount[j] = p;
      }
}

static void addEntry(const char* n) {
  if (cnt >= MAXF) return;
  if (n[0] == '.' || strlen(n) > 150) return;
  if (!strcmp(n, "log.txt") || !strcmp(n, "job.txt")) return;
  char base[160];
  int idx = 0;
  bool isP = partInfo(n, base, sizeof(base), &idx);
  char full[340];
  if (tab == 0) {
    if (isP) return;
    snprintf(full, sizeof(full), "%s/%s", BASE, n);
    long long s = fileSize(full);
    if (s <= 0 || s > 20000000000000LL) return;
    snprintf(names[cnt], sizeof(names[cnt]), "%s", n);
    sizes[cnt] = s;
    pcount[cnt] = 0;
    cnt++;
  } else {
    if (!isP || idx != 1) return;
    long long tot = 0;
    int k = 0;
    for (;;) {
      snprintf(full, sizeof(full), "%s/%s.part%d", BASE, base, k + 1);
      long long s = fileSize(full);
      if (s < 0) break;
      tot += s;
      k++;
    }
    snprintf(names[cnt], sizeof(names[cnt]), "%s", base);
    sizes[cnt] = tot;
    pcount[cnt] = k;
    cnt++;
  }
}

#if USE_GD
extern "C" int ui_kopen(const char*, int, int) __asm__("sceKernelOpen");
extern "C" int ui_kclose(int) __asm__("sceKernelClose");
extern "C" int ui_kgetdents(int, char*, int) __asm__("sceKernelGetdents");

static int parseDirents(const char* buf, int n) {
  int off = 0, found = 0;
  while (off + 8 < n) {
    unsigned short reclen = *(const unsigned short*)(buf + off + 4);
    unsigned char namlen = *(const unsigned char*)(buf + off + 7);
    const char* nm = buf + off + 8;
    if (reclen < 8 || off + reclen > n) break;
    if (namlen > 0 && namlen <= 150 && nm[namlen] == 0) {
      found++;
      addEntry(nm);
    }
    off += reclen;
  }
  return found;
}

static void gdScan() {
  int fd = ui_kopen(BASE, 0, 0);
  if (fd < 0) { snprintf(dbgNote, sizeof(dbgNote), "getdents: open failed (%d)", fd); return; }
  static char gbuf[8192] __attribute__((aligned(8)));
  int total = 0, n = 0, rounds = 0;
  while ((n = ui_kgetdents(fd, gbuf, sizeof(gbuf))) > 0 && rounds < 64) {
    total += parseDirents(gbuf, n);
    rounds++;
  }
  ui_kclose(fd);
  snprintf(dbgNote, sizeof(dbgNote), "getdents: entries=%d last=%d", total, n);
}
#endif

static void scan() {
  cnt = 0; sel = 0; scroll = 0; dbgRaw = 0;
  snprintf(dbgNote, sizeof(dbgNote), "scan: not run");
#if USE_DIR
  DIR* d = opendir(BASE);
  if (!d) {
    snprintf(dbgNote, sizeof(dbgNote), "opendir failed");
    LOGF("opendir failed");
  } else {
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
      dbgRaw++;
      addEntry(e->d_name);
    }
    closedir(d);
    snprintf(dbgNote, sizeof(dbgNote), "opendir ok: entries=%d shown=%d", dbgRaw, cnt);
  }
#endif
#if USE_GD
  if (cnt == 0) gdScan();
#endif
  sortList();
  LOGF(dbgNote);
}

static void onSelect() {
  if (cnt == 0) return;
  int need = (int)((sizes[sel] + 3999999999LL) / 4000000000LL);
  if (need < 2) need = 2;
  minParts = need;
  if (parts < need) parts = need;
  if (tab == 0 && parts > need + 8) parts = need;
}

static void padInit() {
#if USE_PAD
  int32_t uid = 0;
  sceUserServiceInitialize(NULL);
  if (sceUserServiceGetInitialUser(&uid) != 0) { LOGF("no initial user"); return; }
  scePadInit();
  int32_t h = scePadOpen(uid, 0, 0, NULL);
  if (h > 0) { padH = h; padOk = 1; LOGF("pad ok"); }
  else LOGF("pad open failed");
#endif
}

static uint32_t padPressed() {
#if USE_PAD
  if (!padOk) return 0;
  OrbisPadData d;
  memset(&d, 0, sizeof(d));
  if (scePadReadState(padH, &d) != 0) return 0;
  uint32_t b = d.buttons;
  uint32_t p = b & ~prevB;
  prevB = b;
  return p;
#else
  return 0;
#endif
}

static bool runJobFile() {
  FILE* j = fopen(BASE "/job.txt", "r");
  if (!j) return false;
  char md[32] = "", nm[256] = "", np[32] = "";
  fgets(md, sizeof(md), j);
  fgets(nm, sizeof(nm), j);
  fgets(np, sizeof(np), j);
  fclose(j);
  md[strcspn(md, "\r\n")] = 0;
  nm[strcspn(nm, "\r\n")] = 0;
  mode = 1;
  if (!strcmp(md, "split")) { tab = 0; doSplit(nm, atoi(np)); }
  else if (!strcmp(md, "merge")) { tab = 1; doMerge(nm); }
  else { resetWork(nm); fail("job.txt: mode must be split or merge"); }
  mode = 2;
  return true;
}

int main() {
  lg = fopen(BASE "/log.txt", "w");
  sc = new Scene2D(FW, FH, 4);
  if (!sc->Init(0xC000000, 2)) {
    LOGF("video init failed");
    sc = NULL;
  }
#ifdef GRAPHICS_USES_FONT
  if (sc) {
    haveFont = sc->InitFont(&fBig, PS4UI_FONT, 56) && sc->InitFont(&fMid, PS4UI_FONT, 38) && sc->InitFont(&fSm, PS4UI_FONT, 28);
    LOGF(haveFont ? "font ok" : "font failed - using pixel font");
  }
#endif
  padInit();
  scan();
  onSelect();
  render();
  if (!padOk) {
    if (runJobFile()) render();
    time_t end = time(NULL) + 120;
    while (time(NULL) < end) {
      render();
      sceKernelUsleep(500000);
    }
    if (lg) fclose(lg);
    return 0;
  }
  bool dirty = true;
  time_t lastR = 0;
  for (;;) {
    uint32_t p = padPressed();
    if (p & B_OPTIONS) break;
    if (mode == 0) {
      if (p & (B_L1 | B_R1)) { tab ^= 1; scan(); onSelect(); dirty = true; }
      if ((p & B_DOWN) && sel + 1 < cnt) { sel++; if (sel >= scroll + 9) scroll = sel - 8; onSelect(); dirty = true; }
      if ((p & B_UP) && sel > 0) { sel--; if (sel < scroll) scroll = sel; onSelect(); dirty = true; }
      if (tab == 0 && cnt > 0) {
        if (p & B_RIGHT) { if (parts < 99) parts++; dirty = true; }
        if (p & B_LEFT) { if (parts > minParts) parts--; dirty = true; }
      }
      if (p & B_TRI) { scan(); onSelect(); dirty = true; }
      if ((p & B_CROSS) && cnt > 0) {
        char nm[160];
        snprintf(nm, sizeof(nm), "%s", names[sel]);
        mode = 1;
        if (tab == 0) doSplit(nm, parts); else doMerge(nm);
        mode = 2;
        dirty = true;
      }
    } else if (mode == 2) {
      if (p & (B_CROSS | B_CIRCLE)) { mode = 0; scan(); onSelect(); dirty = true; }
    }
    time_t n = time(NULL);
    if (dirty || n - lastR >= 2) { render(); dirty = false; lastR = n; }
    sceKernelUsleep(30000);
  }
  if (lg) fclose(lg);
  return 0;
}
