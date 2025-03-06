//
//  ImageLoader.m
//
//  Created by Francis Grolemund on 11/9/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import "ImageLoader.h"

#include <stdlib.h>
#include <string.h>
#define njAllocMem malloc
#define njFreeMem  free
#define njFillMem  memset
#define njCopyMem  memcpy
#define NJ_INLINE
#define NJ_FORCE_INLINE

typedef struct _nj_code {
    unsigned char bits, code;
} nj_vlc_code_t;

typedef struct _nj_cmp {
    int cid;
    int ssx, ssy;
    int width, height;
    int stride;
    int qtsel;
    int actabsel, dctabsel;
    int dcpred;
    unsigned char *pixels;
} nj_component_t;

typedef struct _nj_ctx {
    nj_result_t error;
    const unsigned char *pos;
    int size;
    int length;
    int width, height;
    int mbwidth, mbheight;
    int mbsizex, mbsizey;
    int ncomp;
    nj_component_t comp[3];
    int qtused, qtavail;
    unsigned char qtab[4][64];
    nj_vlc_code_t vlctab[4][65536];
    int buf, bufbits;
    int block[64];
    int rstinterval;
    unsigned char *rgb;
    
} nj_context_t;

static nj_context_t nj;

static const char njZZ[64] = { 0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18,
    11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35,
    42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45,
    38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

#define W1 2841
#define W2 2676
#define W3 2408
#define W5 1609
#define W6 1108
#define W7 565

#define njThrow(e) do { nj.error = e; return; } while (0)
#define njCheckError() do { if (nj.error) return; } while (0)

@implementation ImageLoader

+(unsigned char) njClip:(const int) x
{
    return (x < 0) ? 0 : ((x > 0xFF) ? 0xFF : (unsigned char) x);
}

+(void) njRowIDCT:(int*) blk
{
    int x0, x1, x2, x3, x4, x5, x6, x7, x8;
    if (!((x1 = blk[4] << 11)
          | (x2 = blk[6])
          | (x3 = blk[2])
          | (x4 = blk[1])
          | (x5 = blk[7])
          | (x6 = blk[5])
          | (x7 = blk[3])))
    {
        blk[0] = blk[1] = blk[2] = blk[3] = blk[4] = blk[5] = blk[6] = blk[7] = blk[0] << 3;
        return;
    }
    x0 = (blk[0] << 11) + 128;
    x8 = W7 * (x4 + x5);
    x4 = x8 + (W1 - W7) * x4;
    x5 = x8 - (W1 + W7) * x5;
    x8 = W3 * (x6 + x7);
    x6 = x8 - (W3 - W5) * x6;
    x7 = x8 - (W3 + W5) * x7;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2);
    x2 = x1 - (W2 + W6) * x2;
    x3 = x1 + (W2 - W6) * x3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    blk[0] = (x7 + x1) >> 8;
    blk[1] = (x3 + x2) >> 8;
    blk[2] = (x0 + x4) >> 8;
    blk[3] = (x8 + x6) >> 8;
    blk[4] = (x8 - x6) >> 8;
    blk[5] = (x0 - x4) >> 8;
    blk[6] = (x3 - x2) >> 8;
    blk[7] = (x7 - x1) >> 8;
}

+(void) njColIDCT:(const int*) blk andOut:(unsigned char *)out andStride:(int) stride
{
    int x0, x1, x2, x3, x4, x5, x6, x7, x8;
    if (!((x1 = blk[8*4] << 8)
          | (x2 = blk[8*6])
          | (x3 = blk[8*2])
          | (x4 = blk[8*1])
          | (x5 = blk[8*7])
          | (x6 = blk[8*5])
          | (x7 = blk[8*3])))
    {
        x1 = [ImageLoader njClip:(((blk[0] + 32) >> 6) + 128)];
        for (x0 = 8;  x0;  --x0) {
            *out = (unsigned char) x1;
            out += stride;
        }
        return;
    }
    x0 = (blk[0] << 8) + 8192;
    x8 = W7 * (x4 + x5) + 4;
    x4 = (x8 + (W1 - W7) * x4) >> 3;
    x5 = (x8 - (W1 + W7) * x5) >> 3;
    x8 = W3 * (x6 + x7) + 4;
    x6 = (x8 - (W3 - W5) * x6) >> 3;
    x7 = (x8 - (W3 + W5) * x7) >> 3;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2) + 4;
    x2 = (x1 - (W2 + W6) * x2) >> 3;
    x3 = (x1 + (W2 - W6) * x3) >> 3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    *out = [self njClip:(((x7 + x1) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x3 + x2) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x0 + x4) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x8 + x6) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x8 - x6) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x0 - x4) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x3 - x2) >> 14) + 128)];  out += stride;
    *out = [self njClip:(((x7 - x1) >> 14) + 128)];
}

+(int) njShowBits:(int) bits
{
    unsigned char newbyte;
    if (!bits) return 0;
    while (nj.bufbits < bits) {
        if (nj.size <= 0) {
            nj.buf = (nj.buf << 8) | 0xFF;
            nj.bufbits += 8;
            continue;
        }
        newbyte = *nj.pos++;
        nj.size--;
        nj.bufbits += 8;
        nj.buf = (nj.buf << 8) | newbyte;
        if (newbyte == 0xFF) {
            if (nj.size) {
                unsigned char marker = *nj.pos++;
                nj.size--;
                switch (marker) {
                    case 0x00:
                    case 0xFF:
                        break;
                    case 0xD9: nj.size = 0; break;
                    default:
                        if ((marker & 0xF8) != 0xD0)
                            nj.error = NJ_SYNTAX_ERROR;
                        else {
                            nj.buf = (nj.buf << 8) | marker;
                            nj.bufbits += 8;
                        }
                }
            } else
                nj.error = NJ_SYNTAX_ERROR;
        }
    }
    return (nj.buf >> (nj.bufbits - bits)) & ((1 << bits) - 1);
}

+(void) njSkipBits:(int) bits
{
    if (nj.bufbits < bits)
        [ImageLoader njShowBits:(bits)];
    nj.bufbits -= bits;
}

+(int) njGetBits:(int) bits
{
    int res = [ImageLoader njShowBits:(bits)];
    [ImageLoader njSkipBits:(bits)];
    return res;
}

+(void) njByteAlign
{
    nj.bufbits &= 0xF8;
}

+(void) njSkip:(int) count
{
    nj.pos += count;
    nj.size -= count;
    nj.length -= count;
    if (nj.size < 0)
        nj.error = NJ_SYNTAX_ERROR;
}

+(unsigned short) njDecode16:(const unsigned char *)pos
{
    return (pos[0] << 8) | pos[1];
}

+(void) njDecodeLength
{
    if (nj.size < 2)
        njThrow(NJ_SYNTAX_ERROR);
    nj.length = [ImageLoader njDecode16:(nj.pos)];
    if (nj.length > nj.size)
        njThrow(NJ_SYNTAX_ERROR);
    [self njSkip:(2)];
}

+(void) njSkipMarker
{
    [ImageLoader njDecodeLength];
    [ImageLoader njSkip:(nj.length)];
}

+(void) njDecodeSOF
{
    int i, ssxmax = 0, ssymax = 0;
    nj_component_t* c;
    [ImageLoader njDecodeLength];
    if (nj.length < 9)
        njThrow(NJ_SYNTAX_ERROR);
    if (nj.pos[0] != 8) njThrow(NJ_UNSUPPORTED);
    nj.height = [self njDecode16:(nj.pos+1)];
    nj.width = [self njDecode16:(nj.pos+3)];
    nj.ncomp = nj.pos[5];
    [self njSkip:(6)];
    switch (nj.ncomp) {
        case 1:
        case 3:
            break;
        default:
            njThrow(NJ_UNSUPPORTED);
    }
    if (nj.length < (nj.ncomp * 3))
        njThrow(NJ_SYNTAX_ERROR);
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        c->cid = nj.pos[0];
        if (!(c->ssx = nj.pos[1] >> 4))
            njThrow(NJ_SYNTAX_ERROR);
        if (c->ssx & (c->ssx - 1)) njThrow(NJ_UNSUPPORTED);  // non-power of two
        if (!(c->ssy = nj.pos[1] & 15))
            njThrow(NJ_SYNTAX_ERROR);
        if (c->ssy & (c->ssy - 1)) njThrow(NJ_UNSUPPORTED);  // non-power of two
        if ((c->qtsel = nj.pos[2]) & 0xFC)
            njThrow(NJ_SYNTAX_ERROR);
        [self njSkip:(3)];
        nj.qtused |= 1 << c->qtsel;
        if (c->ssx > ssxmax) ssxmax = c->ssx;
        if (c->ssy > ssymax) ssymax = c->ssy;
    }
    if (nj.ncomp == 1) {
        c = nj.comp;
        c->ssx = c->ssy = ssxmax = ssymax = 1;
    }
    nj.mbsizex = ssxmax << 3;
    nj.mbsizey = ssymax << 3;
    nj.mbwidth = (nj.width + nj.mbsizex - 1) / nj.mbsizex;
    nj.mbheight = (nj.height + nj.mbsizey - 1) / nj.mbsizey;
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        c->width = (nj.width * c->ssx + ssxmax - 1) / ssxmax;
        c->stride = (c->width + 7) & 0x7FFFFFF8;
        c->height = (nj.height * c->ssy + ssymax - 1) / ssymax;
        c->stride = nj.mbwidth * nj.mbsizex * c->ssx / ssxmax;
        if (((c->width < 3) && (c->ssx != ssxmax)) || ((c->height < 3) && (c->ssy != ssymax))) njThrow(NJ_UNSUPPORTED);
        if (!(c->pixels = njAllocMem(c->stride * (nj.mbheight * nj.mbsizey * c->ssy / ssymax)))) njThrow(NJ_OUT_OF_MEM);
    }
    if (nj.ncomp == 3) {
        nj.rgb = njAllocMem(nj.width * nj.height * nj.ncomp);
        if (!nj.rgb) njThrow(NJ_OUT_OF_MEM);
    }
    [self njSkip:(nj.length)];
}

+(void) njDecodeDHT
{
    int codelen, currcnt, remain, spread, i, j;
    nj_vlc_code_t *vlc;
    static unsigned char counts[16];
    [self njDecodeLength];
    while (nj.length >= 17) {
        i = nj.pos[0];
        if (i & 0xEC)
            njThrow(NJ_SYNTAX_ERROR);
        if (i & 0x02)
            njThrow(NJ_UNSUPPORTED);
        i = (i | (i >> 3)) & 3;  // combined DC/AC + tableid value
        for (codelen = 1;  codelen <= 16;  ++codelen)
            counts[codelen - 1] = nj.pos[codelen];
        [self njSkip:(17)];
        vlc = &nj.vlctab[i][0];
        remain = spread = 65536;
        for (codelen = 1;  codelen <= 16;  ++codelen) {
            spread >>= 1;
            currcnt = counts[codelen - 1];
            if (!currcnt) continue;
            if (nj.length < currcnt)
                njThrow(NJ_SYNTAX_ERROR);
            remain -= currcnt << (16 - codelen);
            if (remain < 0)
                njThrow(NJ_SYNTAX_ERROR);
            for (i = 0;  i < currcnt;  ++i) {
                register unsigned char code = nj.pos[i];
                for (j = spread;  j;  --j) {
                    vlc->bits = (unsigned char) codelen;
                    vlc->code = code;
                    ++vlc;
                }
            }
            [self njSkip:(currcnt)];
        }
        while (remain--) {
            vlc->bits = 0;
            ++vlc;
        }
        
        //  DEBUG:
#if 0
        NSLog(@"READ-HT: %2x", i);
        for (int x = 0; x < 256; x++) {
            if (nj.vlctab[i][x].bits == 0) {
                continue;
            }
            NSLog(@" %d. code(%02x) bits(%02x)", x, nj.vlctab[i][x].code, nj.vlctab[i][x].bits);
        }
        //  DEBUG
#endif        
    }

    if (nj.length)
        njThrow(NJ_SYNTAX_ERROR);
}

+(void) njDecodeDQT
{
    int i;
    unsigned char *t;
    [ImageLoader njDecodeLength];
    while (nj.length >= 65) {
        i = nj.pos[0];
        if (i & 0xFC)
            njThrow(NJ_SYNTAX_ERROR);
        nj.qtavail |= 1 << i;
        t = &nj.qtab[i][0];
        for (i = 0;  i < 64;  ++i)
            t[i] = nj.pos[i + 1];
        [self njSkip:(65)];
    }
    if (nj.length)
        njThrow(NJ_SYNTAX_ERROR);
}

+(void) njDecodeDRI
{
    [ImageLoader njDecodeLength];
    if (nj.length < 2)
        njThrow(NJ_SYNTAX_ERROR);
    nj.rstinterval = [self njDecode16:(nj.pos)];
    [self njSkip:(nj.length)];
}

+(int) njGetVLC:(nj_vlc_code_t*) vlc andCode:(unsigned char*) code
{
    int value = [ImageLoader njShowBits:(16)];
    int bits = vlc[value].bits;
    if (!bits) {
        nj.error = NJ_SYNTAX_ERROR;
        return 0;
    }
    [self njSkipBits:(bits)];
    value = vlc[value].code;
    if (code) *code = (unsigned char) value;
    bits = value & 15;
    if (!bits) return 0;
    value = [self njGetBits:(bits)];
    if (value < (1 << (bits - 1)))
        value += ((-1) << bits) + 1;
    return value;
}

+(void) dumpDU
{
    return;
    NSLog(@"READER:");
    NSString *tmp = @"";
    for (int i = 0; i < 64; i++) {
        if (i % 8 == 0) {
            tmp = @"";
        }
        tmp = [tmp stringByAppendingFormat:@"%6d ", nj.block[i]];
        if (i % 8 == 7) {
            NSLog(@"%@", tmp);
        }
    }
}

+(void) njDecodeBlock:(nj_component_t*) c andOut:(unsigned char*) out
{
    unsigned char code = 0;
    int value, coef = 0;
    njFillMem(nj.block, 0, sizeof(nj.block));
    c->dcpred += [self njGetVLC:(&nj.vlctab[c->dctabsel][0]) andCode: NULL];
    nj.block[0] = (c->dcpred) * nj.qtab[c->qtsel][0];
    do {
        value = [self njGetVLC:(&nj.vlctab[c->actabsel][0]) andCode: &code];
        if (!code) break;  // EOB
        if (!(code & 0x0F) && (code != 0xF0))
            njThrow(NJ_SYNTAX_ERROR);
        coef += (code >> 4) + 1;
        if (coef > 63)
            njThrow(NJ_SYNTAX_ERROR);
        nj.block[(int) njZZ[coef]] = value * nj.qtab[c->qtsel][coef];
    } while (coef < 63);
    
    [ImageLoader dumpDU];
    
    for (coef = 0;  coef < 64;  coef += 8)
        [self njRowIDCT:(&nj.block[coef])];
    for (coef = 0;  coef < 8;  ++coef)
        [self njColIDCT:(&nj.block[coef]) andOut:&out[coef] andStride: c->stride];
}

+(void) njDecodeScan
{
    int i, mbx, mby, sbx, sby;
    int rstcount = nj.rstinterval, nextrst = 0;
    nj_component_t* c;
    [ImageLoader njDecodeLength];
    if (nj.length < (4 + 2 * nj.ncomp))
        njThrow(NJ_SYNTAX_ERROR);
    if (nj.pos[0] != nj.ncomp)
        njThrow(NJ_UNSUPPORTED);
    [ImageLoader njSkip:(1)];
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        if (nj.pos[0] != c->cid)
            njThrow(NJ_SYNTAX_ERROR);
        if (nj.pos[1] & 0xEE)
            njThrow(NJ_SYNTAX_ERROR);
        c->dctabsel = nj.pos[1] >> 4;
        c->actabsel = (nj.pos[1] & 1) | 2;
        [self njSkip:(2)];
    }
    if (nj.pos[0] || (nj.pos[1] != 63) || nj.pos[2])
        njThrow(NJ_UNSUPPORTED);
    [self njSkip:(nj.length)];
    for (mbx = mby = 0;;) {
        for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c)
            for (sby = 0;  sby < c->ssy;  ++sby)
                for (sbx = 0;  sbx < c->ssx;  ++sbx) {
                    [ImageLoader njDecodeBlock:c andOut:(&c->pixels[((mby * c->ssy + sby) * c->stride + mbx * c->ssx + sbx) << 3])];
                    njCheckError();
                }
        if (++mbx >= nj.mbwidth) {
            mbx = 0;
            if (++mby >= nj.mbheight) break;
        }
        if (nj.rstinterval && !(--rstcount)) {
            [self njByteAlign];
            i = [self njGetBits:(16)];
            if (((i & 0xFFF8) != 0xFFD0) || ((i & 7) != nextrst))
                njThrow(NJ_SYNTAX_ERROR);
            nextrst = (nextrst + 1) & 7;
            rstcount = nj.rstinterval;
            for (i = 0;  i < 3;  ++i)
                nj.comp[i].dcpred = 0;
        }
    }
    nj.error = __NJ_FINISHED;
}

+(void) njUpsample:(nj_component_t*) c
{
    int x, y, xshift = 0, yshift = 0;
    unsigned char *out, *lin, *lout;
    while (c->width < nj.width) { c->width <<= 1; ++xshift; }
    while (c->height < nj.height) { c->height <<= 1; ++yshift; }
    out = njAllocMem(c->width * c->height);
    if (!out) njThrow(NJ_OUT_OF_MEM);
    lin = c->pixels;
    lout = out;
    for (y = 0;  y < c->height;  ++y) {
        lin = &c->pixels[(y >> yshift) * c->stride];
        for (x = 0;  x < c->width;  ++x)
            lout[x] = lin[x >> xshift];
        lout += c->width;
    }
    c->stride = c->width;
    njFreeMem(c->pixels);
    c->pixels = out;
}

+(void) njConvert
{
    int i;
    nj_component_t* c;
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
#if NJ_CHROMA_FILTER
        while ((c->width < nj.width) || (c->height < nj.height)) {
            if (c->width < nj.width) njUpsampleH(c);
            njCheckError();
            if (c->height < nj.height) njUpsampleV(c);
            njCheckError();
        }
#else
        if ((c->width < nj.width) || (c->height < nj.height))
            [ImageLoader njUpsample:(c)];
#endif
        if ((c->width < nj.width) || (c->height < nj.height)) njThrow(NJ_INTERNAL_ERR);
    }
    if (nj.ncomp == 3) {
        // convert to RGB
        int x, yy;
        unsigned char *prgb = nj.rgb;
        const unsigned char *py  = nj.comp[0].pixels;
        const unsigned char *pcb = nj.comp[1].pixels;
        const unsigned char *pcr = nj.comp[2].pixels;
        for (yy = nj.height;  yy;  --yy) {
            for (x = 0;  x < nj.width;  ++x) {
                register int y = py[x] << 8;
                register int cb = pcb[x] - 128;
                register int cr = pcr[x] - 128;
                *prgb++ = [self njClip:((y            + 359 * cr + 128) >> 8)];
                *prgb++ = [self njClip:((y -  88 * cb - 183 * cr + 128) >> 8)];
                *prgb++ = [self njClip:((y + 454 * cb            + 128) >> 8)];
            }
            py += nj.comp[0].stride;
            pcb += nj.comp[1].stride;
            pcr += nj.comp[2].stride;
        }
    } else if (nj.comp[0].width != nj.comp[0].stride) {
        // grayscale -> only remove stride
        unsigned char *pin = &nj.comp[0].pixels[nj.comp[0].stride];
        unsigned char *pout = &nj.comp[0].pixels[nj.comp[0].width];
        int y;
        for (y = nj.comp[0].height - 1;  y;  --y) {
            njCopyMem(pout, pin, nj.comp[0].width);
            pin += nj.comp[0].stride;
            pout += nj.comp[0].width;
        }
        nj.comp[0].stride = nj.comp[0].width;
    }
}

+(void) njInit
{
    njFillMem(&nj, 0, sizeof(nj_context_t));
}

+(void) njDone
{
    int i;
    for (i = 0;  i < 3;  ++i)
        if (nj.comp[i].pixels) njFreeMem((void*) nj.comp[i].pixels);
    if (nj.rgb) njFreeMem((void*) nj.rgb);
    [ImageLoader njInit];
}

+(nj_result_t) njDecode:(const void*) jpeg andSize:(const int) size
{
    [ImageLoader njDone];
    nj.pos = (const unsigned char*) jpeg;
    nj.size = size & 0x7FFFFFFF;
    if (nj.size < 2) return NJ_NO_JPEG;
    if ((nj.pos[0] ^ 0xFF) | (nj.pos[1] ^ 0xD8)) return NJ_NO_JPEG;
    [ImageLoader njSkip:(2)];
    while (!nj.error) {
        if ((nj.size < 2) || (nj.pos[0] != 0xFF))
            return NJ_SYNTAX_ERROR;
        [self njSkip:(2)];
        switch (nj.pos[-1]) {
            case 0xC0: [self njDecodeSOF];  break;
            case 0xC4: [self njDecodeDHT];  break;
            case 0xDB: [self njDecodeDQT];  break;
            case 0xDD: [self njDecodeDRI];  break;
            case 0xDA: [self njDecodeScan]; break;
            case 0xFE: [self njSkipMarker]; break;
            default:
                if ((nj.pos[-1] & 0xF0) == 0xE0)
                    [self njSkipMarker];
                else
                    return NJ_UNSUPPORTED;
        }
    }
    if (nj.error != __NJ_FINISHED) return nj.error;
    nj.error = NJ_OK;
    [ImageLoader njConvert];
    return nj.error;
}

+(int) njGetWidth
{
    return nj.width;
}

+(int) njGetHeight
{
    return nj.height;
}

+(int) njIsColor
{
    return (nj.ncomp != 1);
}

+(unsigned char*) njGetImage
{
    return (nj.ncomp == 1) ? nj.comp[0].pixels : nj.rgb;
}

+(int) njGetImageSize
{
    return nj.width * nj.height * nj.ncomp;
}


/*
 *  Initialize the class
 */
+(void) initialize
{
    [ImageLoader njInit];
}

/*
 *  Attempt to unpack the data from the image.
 */
+(nj_result_t) unpackImageData:(NSData *) jpegImage
{
    return [ImageLoader njDecode:[jpegImage bytes] andSize:(int) [jpegImage length]];
}

@end
