//
//  CS_qr_encode_defs.h
//  ChatSeal
//
//  Created by Francis Grolemund on 2/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//  NOTE:  This is port of QR_Encode written by Psytec, Inc. version 1.22 from 2006/05/17

typedef struct tagRS_BLOCKINFO
{
	int ncRSBlock;                  // Number of RS block
	int ncAllCodeWord;              // The number of code words in the block.
	int ncDataCodeWord;             // Number of data codewords (codeword number - the number of RS code word)
    
} CS_QRE_RS_BLOCKINFO, *LPCS_QRE_RS_BLOCKINFO;

//  - QR code version relevant information (model number)
typedef struct tagQR_VERSIONINFO
{
	int nVersionNo;                         // Version number (part number) (1-40)
	int ncAllCodeWord;                      // Total number of codewords
    
	int ncDataCodeWord[4];                  // Number of data code words (the total number of code words - the number of RS code word)
    
	int ncAlignPoint;                       // Number of coordinate alignment pattern
	int nAlignPoint[6];                     // Alignment pattern center coordinates
    
	CS_QRE_RS_BLOCKINFO RS_BlockInfo1[4];   // RS information block (1)
	CS_QRE_RS_BLOCKINFO RS_BlockInfo2[4];   // RS information block (2)
    
} CS_QRE_VERSIONINFO, *LPCS_QRE_VERSIONINFO;

//  - external data
extern CS_QRE_VERSIONINFO CS_QRE_VersionInfo[];
extern unsigned char CS_QRE_byExpToInt[];
extern unsigned char CS_QRE_byIntToExp[];
extern unsigned char *CS_QRE_byRSExp[];
extern int CS_QRE_nIndicatorLenNumeral[];
extern int CS_QRE_nIndicatorLenAlphabet[];
extern int CS_QRE_nIndicatorLen8Bit[];
extern int CS_QRE_nIndicatorLenKanji[];

//  - defines
//  - data mode
#define CS_QRE_MODE_NUMERAL		 0
#define CS_QRE_MODE_ALPHABET     1
#define CS_QRE_MODE_8BIT         2
#define CS_QRE_MODE_KANJI        3

// - group version (model number)
#define CS_QRE_VRESION_S         0      // 1  - 9
#define CS_QRE_VRESION_M         1      // 10 - 26
#define CS_QRE_VRESION_L         2      // 27 - 40

#define CS_QRE_MAX_ALLCODEWORD	 3706   // Maximum total number of codewords
#define CS_QRE_MAX_DATACODEWORD  2956   // Maximum data code word (version 40-L)
#define CS_QRE_MAX_CODEBLOCK	 153    // (Including the RS code word) maximum number of block data codewords
#define CS_QRE_MAX_MODULESIZE	 177    // Maximum number of modules one side
