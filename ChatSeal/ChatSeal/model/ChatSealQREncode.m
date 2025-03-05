//
//  ChatSealQREncode.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

//  NOTE:  This is port of QR_Encode written by Psytec, Inc. version 1.22 from 2006/05/17

#import <QuartzCore/QuartzCore.h>
#import "ChatSealQREncode.h"
#import "CS_qr_encode_defs.h"
#import "ChatSeal.h"

//  - constants
static const int CS_QR_QUIET_MULTIPLIER = 4;

//  - forward declarations
@interface ChatSealQREncode (internal)
-(BOOL) encodeQRString:(NSString *) toEncode asVersion:(NSUInteger) version andLevel:(ps_qre_error_correction_t) level andMask:(ps_qre_masking_pattern_t) mask
             withError:(NSError **) err;
-(BOOL) isKanjiData:(unsigned char) c1 andChar2:(unsigned char) c2;
-(BOOL) isNumeralData:(unsigned char) c;
-(BOOL) isAlphabetData:(unsigned char) c;
-(int) getBitLength:(unsigned char) nMode withDataLen:(int) ncData andGroup:(int) nVerGroup;
-(int) setBitStreamWIthIndex:(int) nIndex andData:(uint16_t) wData andLenData:(int) ncData;
-(unsigned char) alphabetToBinaly:(unsigned char) c;
-(uint16_t) kanjiToBinaly:(uint16_t) wc;
-(int) getEncodeVersion:(int) nVersion withData:(NSString *) toEncode;
-(void) getRSCodeWord:(unsigned char *) lpbyRSWork withNumData:(int) ncDataCodeWord andNumCode:(int) ncRSCodeWord;
-(void) formatModule;
-(void) setFunctionModule;
-(void) setFinderPatternWithX:(int) x andY:(int) y;
-(void) setVersionPattern;
-(void) setAlignmentPatternWithX:(int) x andY:(int) y;
-(void) setCodeWordPattern;
-(void) setMaskingPatternWithNumber:(int) nPatternNo;
-(void) setFormatInfoPatternWithNumber:(int) nPatternNo;
-(int) countPenalty;
@end

/*********************
 ChatSealQREncode
 *********************/
@implementation ChatSealQREncode
/*
 *  Object attributes.
 */
{
	int m_nLevel;
	int m_nVersion;
	int m_nMaskingNo;
	int m_nSymbleSize;
	unsigned char m_byModuleData[CS_QRE_MAX_MODULESIZE][CS_QRE_MAX_MODULESIZE]; // [x][y]
    
	int m_ncDataCodeWordBit;
	unsigned char m_byDataCodeWord[CS_QRE_MAX_DATACODEWORD];
	int m_ncDataBlock;
	unsigned char m_byBlockMode[CS_QRE_MAX_DATACODEWORD];
	int m_nBlockLength[CS_QRE_MAX_DATACODEWORD];
    
	int m_ncAllCodeWord;
	unsigned char m_byAllCodeWord[CS_QRE_MAX_ALLCODEWORD];
	unsigned char m_byRSWork[CS_QRE_MAX_CODEBLOCK];
}


/*
 *  Encode a string into a QR symbol.
 *  - note that the block width is the number of pixels per block in the result.
 */
+(UIImage *) encodeQRString:(NSString *) toEncode asVersion:(NSUInteger) version andLevel:(ps_qre_error_correction_t) level andMask:(ps_qre_masking_pattern_t) mask andTargetDimension:(CGFloat) targetDimension withError:(NSError **) err
{
    UIImage *ret = nil;
    ChatSealQREncode *qre = [[[ChatSealQREncode alloc] init] autorelease];
    if ([qre encodeQRString:toEncode asVersion:version andLevel:level andMask:mask withError:err]) {
        int oneSide = qre->m_nSymbleSize;
        int totalBlocks = oneSide + (CS_QR_QUIET_MULTIPLIER * 2);  //  blocks and quiet region
        
        //  - the target dimension must be at least big enough to fit
        //    blocks that are one pixel wide.
        if (targetDimension < totalBlocks) {
            [CS_error fillError:err withCode:CSErrorQREncodingFailure andFailureReason:@"The requested output image is too small to fit the content."];
            return nil;
        }
        
        CGFloat pxPerBlock = targetDimension / (CGFloat) totalBlocks;
        CGSize szImge = CGSizeMake(targetDimension, targetDimension);
        UIGraphicsBeginImageContextWithOptions(szImge, YES, 0.0f);
        CGContextSetAllowsAntialiasing(UIGraphicsGetCurrentContext(), false);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor whiteColor] CGColor]);
        CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0.0f, 0.0f, szImge.width, szImge.height));
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor blackColor] CGColor]);
        
        CGFloat codePxSize = (oneSide * pxPerBlock);
        CGFloat quietOffset = (targetDimension - codePxSize) / 2.0f;
        CGFloat curX = 0.0f;
        CGFloat curY = quietOffset;
        for (int y = 0; y < oneSide; y++) {
            curX = quietOffset;
            for (int x = 0; x < oneSide; x++) {
                if (qre->m_byModuleData[x][y]) {
                    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(curX, curY, pxPerBlock, pxPerBlock));
                }
                curX += pxPerBlock;
            }
            curY += pxPerBlock;
        }
        ret = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return ret;
}

@end


/****************************
 ChatSealQREncode (internal)
 ****************************/
@implementation ChatSealQREncode (internal)
/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        m_nLevel = 0;
        m_nVersion = 0;
        m_nMaskingNo = 0;
        m_nSymbleSize = 0;
        memset(m_byModuleData, 0, sizeof(m_byModuleData));
        m_ncDataCodeWordBit = 0;
        memset(m_byDataCodeWord, 0, sizeof(m_byDataCodeWord));
        m_ncDataBlock = 0;
        memset(m_byBlockMode, 0, sizeof(m_byBlockMode));
        
        m_ncAllCodeWord = 0;
        memset(m_byAllCodeWord, 0, sizeof(m_byAllCodeWord));
        memset(m_byRSWork, 0, sizeof(m_byRSWork));
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    
    [super dealloc];
}

/*
 *  Check the appropriate Kanji mode
 *  NOTE: S-JIS is not subject to subsequent EBBFh
 */
-(BOOL) isKanjiData:(unsigned char) c1 andChar2:(unsigned char) c2
{
	if (((c1 >= 0x81 && c1 <= 0x9f) || (c1 >= 0xe0 && c1 <= 0xeb)) && (c2 >= 0x40))
	{
		if ((c1 == 0x9f && c2 > 0xfc) || (c1 == 0xeb && c2 > 0xbf))
			return NO;
        
		return YES;
	}
    
	return NO;
}

/*
 *  Check the appropriate numeric mode
 */
-(BOOL) isNumeralData:(unsigned char) c
{
	if (c >= '0' && c <= '9')
		return YES;
    
	return NO;
}

/*
 *  Check the appropriate alphanumeric mode
 */
-(BOOL) isAlphabetData:(unsigned char) c
{
	if (c >= '0' && c <= '9')
		return YES;
    
	if (c >= 'A' && c <= 'Z')
		return YES;
    
	if (c == ' ' || c == '$' || c == '%' || c == '*' || c == '+' || c == '-' || c == '.' || c == '/' || c == ':')
		return YES;
    
	return NO;
}

/*
 *  Get the bit length
 */
-(int) getBitLength:(unsigned char) nMode withDataLen:(int) ncData andGroup:(int) nVerGroup
{
	int ncBits = 0;
    
	switch (nMode)
	{
        case CS_QRE_MODE_NUMERAL:
            ncBits = 4 + CS_QRE_nIndicatorLenNumeral[nVerGroup] + (10 * (ncData / 3));
            switch (ncData % 3)
		{
            case 1:
                ncBits += 4;
                break;
            case 2:
                ncBits += 7;
                break;
            default: // case 0:
                break;
		}
            
            break;
            
        case CS_QRE_MODE_ALPHABET:
            ncBits = 4 + CS_QRE_nIndicatorLenAlphabet[nVerGroup] + (11 * (ncData / 2)) + (6 * (ncData % 2));
            break;
            
        case CS_QRE_MODE_8BIT:
            ncBits = 4 + CS_QRE_nIndicatorLen8Bit[nVerGroup] + (8 * ncData);
            break;
            
        default: // case QR_MODE_KANJI:
            ncBits = 4 + CS_QRE_nIndicatorLenKanji[nVerGroup] + (13 * (ncData / 2));
            break;
	}
    
	return ncBits;
}

/*
 *  Bit set.
 */
-(int) setBitStreamWIthIndex:(int) nIndex andData:(uint16_t) wData andLenData:(int) ncData
{
	int i;
    
	if (nIndex == -1 || nIndex + ncData > CS_QRE_MAX_DATACODEWORD * 8)
		return -1;
    
	for (i = 0; i < ncData; ++i)
	{
		if (wData & (1 << (ncData - i - 1)))
		{
			m_byDataCodeWord[(nIndex + i) / 8] |= 1 << (7 - ((nIndex + i) % 8));
		}
	}
    
	return nIndex + ncData;
}

/*
 *  Binary character alphanumeric mode
 */
-(unsigned char) alphabetToBinaly:(unsigned char) c
{
	if (c >= '0' && c <= '9') return (unsigned char)(c - '0');
    
	if (c >= 'A' && c <= 'Z') return (unsigned char)(c - 'A' + 10);
    
	if (c == ' ') return 36;
    
	if (c == '$') return 37;
    
	if (c == '%') return 38;
    
	if (c == '*') return 39;
    
	if (c == '+') return 40;
    
	if (c == '-') return 41;
    
	if (c == '.') return 42;
    
	if (c == '/') return 43;
    
	return 44; // c == ':'
}

/*
 *  Binary Kanji character mode
 */
-(uint16_t) kanjiToBinaly:(uint16_t) wc
{
	if (wc >= 0x8140 && wc <= 0x9ffc)
		wc -= 0x8140;
	else // (wc >= 0xe040 && wc <= 0xebbf)
		wc -= 0xc140;
    
	return (uint16_t)(((wc >> 8) * 0xc0) + (wc & 0x00ff));
}

/*
 *  Data input encoding
 */
-(BOOL) encodeSourceData:(NSString *) toEncode ofVersion:(int) nVerGroup
{
    memset(m_nBlockLength, 0, sizeof(m_nBlockLength));
    
	int i, j;
    const char *lpsSource = [toEncode UTF8String];
    int ncLength = (int) [toEncode length];
    
	for (m_ncDataBlock = i = 0; i < ncLength; ++i)
	{
		unsigned char byMode;
        
		if (i < ncLength - 1 && [self isKanjiData:(unsigned char) lpsSource[i] andChar2:(unsigned char) lpsSource[i + 1]])
			byMode = CS_QRE_MODE_KANJI;
		else if ([self isNumeralData:(unsigned char) lpsSource[i]])
			byMode = CS_QRE_MODE_NUMERAL;
		else if ([self isAlphabetData:(unsigned char) lpsSource[i]])
			byMode = CS_QRE_MODE_ALPHABET;
		else
			byMode = CS_QRE_MODE_8BIT;
        
		if (i == 0)
			m_byBlockMode[0] = byMode;
        
		if (m_byBlockMode[m_ncDataBlock] != byMode)
			m_byBlockMode[++m_ncDataBlock] = byMode;
        
		++m_nBlockLength[m_ncDataBlock];
        
		if (byMode == CS_QRE_MODE_KANJI)
		{
			++m_nBlockLength[m_ncDataBlock];
			++i;
		}
	}
    
	++m_ncDataBlock;
    
	int ncSrcBits, ncDstBits;
	int nBlock = 0;
    
	while (nBlock < m_ncDataBlock - 1)
	{
		int ncJoinFront, ncJoinBehind;
		int nJoinPosition = 0;
        
		if ((m_byBlockMode[nBlock] == CS_QRE_MODE_NUMERAL  && m_byBlockMode[nBlock + 1] == CS_QRE_MODE_ALPHABET) ||
			(m_byBlockMode[nBlock] == CS_QRE_MODE_ALPHABET && m_byBlockMode[nBlock + 1] == CS_QRE_MODE_NUMERAL))
		{
            ncSrcBits = [self getBitLength:m_byBlockMode[nBlock] withDataLen:m_nBlockLength[nBlock] andGroup:nVerGroup] +
            [self getBitLength:m_byBlockMode[nBlock + 1] withDataLen:m_nBlockLength[nBlock + 1] andGroup:nVerGroup];
            
            ncDstBits = [self getBitLength:CS_QRE_MODE_ALPHABET withDataLen:m_nBlockLength[nBlock] + m_nBlockLength[nBlock + 1] andGroup:nVerGroup];
            
			if (ncSrcBits > ncDstBits)
			{
				if (nBlock >= 1 && m_byBlockMode[nBlock - 1] == CS_QRE_MODE_8BIT)
				{
                    ncJoinFront = [self getBitLength:CS_QRE_MODE_8BIT withDataLen:m_nBlockLength[nBlock - 1] + m_nBlockLength[nBlock] andGroup:nVerGroup] +
                    [self getBitLength:m_byBlockMode[nBlock + 1] withDataLen:m_nBlockLength[nBlock + 1] andGroup:nVerGroup];
                    
					if (ncJoinFront > ncDstBits + [self getBitLength:CS_QRE_MODE_8BIT withDataLen:m_nBlockLength[nBlock - 1] andGroup:nVerGroup])
						ncJoinFront = 0;
				}
				else
					ncJoinFront = 0;
                
				if (nBlock < m_ncDataBlock - 2 && m_byBlockMode[nBlock + 2] == CS_QRE_MODE_8BIT)
				{
					ncJoinBehind = [self getBitLength:m_byBlockMode[nBlock] withDataLen:m_nBlockLength[nBlock] andGroup:nVerGroup] +
                    [self getBitLength:CS_QRE_MODE_8BIT withDataLen:m_nBlockLength[nBlock + 1] + m_nBlockLength[nBlock + 2] andGroup:nVerGroup];
					if (ncJoinBehind > ncDstBits + [self getBitLength:CS_QRE_MODE_8BIT withDataLen:m_nBlockLength[nBlock + 2] andGroup:nVerGroup])
						ncJoinBehind = 0;
				}
				else
					ncJoinBehind = 0;
                
				if (ncJoinFront != 0 && ncJoinBehind != 0)
				{
					nJoinPosition = (ncJoinFront < ncJoinBehind) ? -1 : 1;
				}
				else
				{
					nJoinPosition = (ncJoinFront != 0) ? -1 : ((ncJoinBehind != 0) ? 1 : 0);
				}
                
				if (nJoinPosition != 0)
				{
					if (nJoinPosition == -1)
					{
						m_nBlockLength[nBlock - 1] += m_nBlockLength[nBlock];
                        
						for (i = nBlock; i < m_ncDataBlock - 1; ++i)
						{
							m_byBlockMode[i]  = m_byBlockMode[i + 1];
							m_nBlockLength[i] = m_nBlockLength[i + 1];
						}
					}
					else
					{
						m_byBlockMode[nBlock + 1] = CS_QRE_MODE_8BIT;
						m_nBlockLength[nBlock + 1] += m_nBlockLength[nBlock + 2];
                        
						for (i = nBlock + 2; i < m_ncDataBlock - 1; ++i)
						{
							m_byBlockMode[i]  = m_byBlockMode[i + 1];
							m_nBlockLength[i] = m_nBlockLength[i + 1];
						}
					}
                    
					--m_ncDataBlock;
				}
				else
				{
					if (nBlock < m_ncDataBlock - 2 && m_byBlockMode[nBlock + 2] == CS_QRE_MODE_ALPHABET)
					{
						m_nBlockLength[nBlock + 1] += m_nBlockLength[nBlock + 2];
                        
						for (i = nBlock + 2; i < m_ncDataBlock - 1; ++i)
						{
							m_byBlockMode[i]  = m_byBlockMode[i + 1];
							m_nBlockLength[i] = m_nBlockLength[i + 1];
						}
                        
						--m_ncDataBlock;
					}
                    
					m_byBlockMode[nBlock] = CS_QRE_MODE_ALPHABET;
					m_nBlockLength[nBlock] += m_nBlockLength[nBlock + 1];
                    
					// å„ë±ÇÉVÉtÉg
					for (i = nBlock + 1; i < m_ncDataBlock - 1; ++i)
					{
						m_byBlockMode[i]  = m_byBlockMode[i + 1];
						m_nBlockLength[i] = m_nBlockLength[i + 1];
					}
                    
					--m_ncDataBlock;
                    
					if (nBlock >= 1 && m_byBlockMode[nBlock - 1] == CS_QRE_MODE_ALPHABET)
					{
						m_nBlockLength[nBlock - 1] += m_nBlockLength[nBlock];
                        
						for (i = nBlock; i < m_ncDataBlock - 1; ++i)
						{
							m_byBlockMode[i]  = m_byBlockMode[i + 1];
							m_nBlockLength[i] = m_nBlockLength[i + 1];
						}
                        
						--m_ncDataBlock;
					}
				}
                
				continue;
			}
		}
        
		++nBlock;
	}
    
	nBlock = 0;
    
	while (nBlock < m_ncDataBlock - 1)
	{
		ncSrcBits = [self getBitLength:m_byBlockMode[nBlock] withDataLen:m_nBlockLength[nBlock] andGroup:nVerGroup] +
        [self getBitLength:m_byBlockMode[nBlock + 1] withDataLen:m_nBlockLength[nBlock + 1] andGroup:nVerGroup];
        
		ncDstBits = [self getBitLength:CS_QRE_MODE_8BIT withDataLen:m_nBlockLength[nBlock] + m_nBlockLength[nBlock + 1] andGroup:nVerGroup];
        
		if (nBlock >= 1 && m_byBlockMode[nBlock - 1] == CS_QRE_MODE_8BIT)
			ncDstBits -= (4 + CS_QRE_nIndicatorLen8Bit[nVerGroup]);
        
		if (nBlock < m_ncDataBlock - 2 && m_byBlockMode[nBlock + 2] == CS_QRE_MODE_8BIT)
			ncDstBits -= (4 + CS_QRE_nIndicatorLen8Bit[nVerGroup]);
        
		if (ncSrcBits > ncDstBits)
		{
			if (nBlock >= 1 && m_byBlockMode[nBlock - 1] == CS_QRE_MODE_8BIT)
			{
				m_nBlockLength[nBlock - 1] += m_nBlockLength[nBlock];
                
				// å„ë±ÇÉVÉtÉg
				for (i = nBlock; i < m_ncDataBlock - 1; ++i)
				{
					m_byBlockMode[i]  = m_byBlockMode[i + 1];
					m_nBlockLength[i] = m_nBlockLength[i + 1];
				}
                
				--m_ncDataBlock;
				--nBlock;
			}
            
			if (nBlock < m_ncDataBlock - 2 && m_byBlockMode[nBlock + 2] == CS_QRE_MODE_8BIT)
			{
				m_nBlockLength[nBlock + 1] += m_nBlockLength[nBlock + 2];
                
				for (i = nBlock + 2; i < m_ncDataBlock - 1; ++i)
				{
					m_byBlockMode[i]  = m_byBlockMode[i + 1];
					m_nBlockLength[i] = m_nBlockLength[i + 1];
				}
                
				--m_ncDataBlock;
			}
            
			m_byBlockMode[nBlock] = CS_QRE_MODE_8BIT;
			m_nBlockLength[nBlock] += m_nBlockLength[nBlock + 1];
            
			for (i = nBlock + 1; i < m_ncDataBlock - 1; ++i)
			{
				m_byBlockMode[i]  = m_byBlockMode[i + 1];
				m_nBlockLength[i] = m_nBlockLength[i + 1];
			}
            
			--m_ncDataBlock;
            
			if (nBlock >= 1)
				--nBlock;
            
			continue;
		}
        
		++nBlock;
	}
    
	int ncComplete = 0;
	uint16_t wBinCode;
    
	m_ncDataCodeWordBit = 0;
    memset(m_byDataCodeWord, 0, CS_QRE_MAX_DATACODEWORD);
    
	for (i = 0; i < m_ncDataBlock && m_ncDataCodeWordBit != -1; ++i)
	{
		if (m_byBlockMode[i] == CS_QRE_MODE_NUMERAL)
		{
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:1 andLenData:4];
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t)m_nBlockLength[i] andLenData:CS_QRE_nIndicatorLenNumeral[nVerGroup]];
            
			for (j = 0; j < m_nBlockLength[i]; j += 3)
			{
				if (j < m_nBlockLength[i] - 2)
				{
					wBinCode = (uint16_t)(((lpsSource[ncComplete + j]	  - '0') * 100) +
                                          ((lpsSource[ncComplete + j + 1] - '0') * 10) +
                                          (lpsSource[ncComplete + j + 2] - '0'));
                    
					m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:wBinCode andLenData: 10];
				}
				else if (j == m_nBlockLength[i] - 2)
				{
					wBinCode = (uint16_t)(((lpsSource[ncComplete + j] - '0') * 10) +
                                          (lpsSource[ncComplete + j + 1] - '0'));
                    
					m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:wBinCode andLenData:7];
				}
				else if (j == m_nBlockLength[i] - 1)
				{
					wBinCode = (uint16_t)(lpsSource[ncComplete + j] - '0');
                    
					m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:wBinCode andLenData:4];
				}
			}
            
			ncComplete += m_nBlockLength[i];
		}
        
		else if (m_byBlockMode[i] == CS_QRE_MODE_ALPHABET)
		{
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:2 andLenData:4];
            
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t)m_nBlockLength[i] andLenData:CS_QRE_nIndicatorLenAlphabet[nVerGroup]];
            
			for (j = 0; j < m_nBlockLength[i]; j += 2)
			{
				if (j < m_nBlockLength[i] - 1)
				{
					wBinCode = (uint16_t)(([self alphabetToBinaly:(unsigned char) lpsSource[ncComplete + j]] * 45) +
                                          [self alphabetToBinaly:(unsigned char) lpsSource[ncComplete + j + 1]]);
                    
                    m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:wBinCode andLenData:11];
                    
				}
				else
				{
					wBinCode = (uint16_t) [self alphabetToBinaly:(unsigned char) lpsSource[ncComplete + j]];
                    
					m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:wBinCode andLenData:6];
				}
			}
            
			ncComplete += m_nBlockLength[i];
		}
        
		else if (m_byBlockMode[i] == CS_QRE_MODE_8BIT)
		{
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:4 andLenData:4];
            
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t)m_nBlockLength[i] andLenData:CS_QRE_nIndicatorLen8Bit[nVerGroup]];
            
			for (j = 0; j < m_nBlockLength[i]; ++j)
			{
				m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t)lpsSource[ncComplete + j] andLenData:8];
			}
            
			ncComplete += m_nBlockLength[i];
		}
		else // m_byBlockMode[i] == QR_MODE_KANJI
		{
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:8 andLenData:4];
            
			m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t)(m_nBlockLength[i] / 2) andLenData:CS_QRE_nIndicatorLenKanji[nVerGroup]];
            
			for (j = 0; j < m_nBlockLength[i] / 2; ++j)
			{
				uint wBinCode2 = [self kanjiToBinaly:(uint16_t)(((unsigned char)lpsSource[ncComplete + (j * 2)] << 8) + (unsigned char)lpsSource[ncComplete + (j * 2) + 1])];
                
				m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:(uint16_t) wBinCode2 andLenData:13];
			}
            
			ncComplete += m_nBlockLength[i];
		}
	}
    
	return (m_ncDataCodeWordBit != -1);
}

/*
 *  Compute the ideal encoding version
 *  - returns 0 if over capacity.
 */
-(int) getEncodeVersion:(int) nVersion withData:(NSString *) toEncode
{
	int nVerGroup = nVersion >= 27 ? CS_QRE_VRESION_L : (nVersion >= 10 ? CS_QRE_VRESION_M : CS_QRE_VRESION_S);
	int i, j;
    
	for (i = nVerGroup; i <= CS_QRE_VRESION_L; ++i)
	{
        if ([self encodeSourceData:toEncode ofVersion:i])
		{
			if (i == CS_QRE_VRESION_S)
			{
				for (j = 1; j <= 9; ++j)
				{
					if ((m_ncDataCodeWordBit + 7) / 8 <= CS_QRE_VersionInfo[j].ncDataCodeWord[m_nLevel])
						return j;
				}
			}
			else if (i == CS_QRE_VRESION_M)
			{
				for (j = 10; j <= 26; ++j)
				{
					if ((m_ncDataCodeWordBit + 7) / 8 <= CS_QRE_VersionInfo[j].ncDataCodeWord[m_nLevel])
						return j;
				}
			}
			else if (i == CS_QRE_VRESION_L)
			{
				for (j = 27; j <= 40; ++j)
				{
					if ((m_ncDataCodeWordBit + 7) / 8 <= CS_QRE_VersionInfo[j].ncDataCodeWord[m_nLevel])
						return j;
				}
			}
		}
	}
    
	return 0;
}

/*
 *  Get code word error correction RS
 */
-(void) getRSCodeWord:(unsigned char *) lpbyRSWork withNumData:(int) ncDataCodeWord andNumCode:(int) ncRSCodeWord
{
	int i, j;
    
	for (i = 0; i < ncDataCodeWord ; ++i)
	{
		if (lpbyRSWork[0] != 0)
		{
			unsigned char nExpFirst = CS_QRE_byIntToExp[lpbyRSWork[0]];
			for (j = 0; j < ncRSCodeWord; ++j)
			{
				unsigned char nExpElement = (unsigned char)(((int)(CS_QRE_byRSExp[ncRSCodeWord][j] + nExpFirst)) % 255);
                
				lpbyRSWork[j] = (unsigned char)(lpbyRSWork[j + 1] ^ CS_QRE_byExpToInt[nExpElement]);
			}
            
			for (j = ncRSCodeWord; j < ncDataCodeWord + ncRSCodeWord - 1; ++j)
				lpbyRSWork[j] = lpbyRSWork[j + 1];
		}
		else
		{
			for (j = 0; j < ncDataCodeWord + ncRSCodeWord - 1; ++j)
				lpbyRSWork[j] = lpbyRSWork[j + 1];
		}
	}
}


/*
 *  Perform data encoding.
 */
-(BOOL) encodeQRString:(NSString *) toEncode asVersion:(NSUInteger) version andLevel:(ps_qre_error_correction_t) level andMask:(ps_qre_masking_pattern_t) mask
             withError:(NSError **) err
{
	int i, j;
    
	m_nLevel = level;
	m_nMaskingNo = mask;
    
    if (!toEncode || [toEncode length] < 1) {
        [CS_error fillError:err withCode:CSErrorInvalidArgument];
        return NO;
    }
    
	int nEncodeVersion = [self getEncodeVersion:(int) version withData:toEncode];
	if (nEncodeVersion == 0) {
        [CS_error fillError:err withCode:CSErrorQREncodingFailure andFailureReason:@"The QR target is not large enough to encode the requested content."];
        return NO;
    }
	
    //  - if the version is not provided, auto-compute it.
	if (version == 0)
	{
        m_nVersion = nEncodeVersion;
	}
	else
	{
		if (nEncodeVersion <= version)
		{
			m_nVersion = (int) version;
		}
		else
		{
            [CS_error fillError:err withCode:CSErrorQREncodingFailure andFailureReason:@"The QR target is not large enough to encode the requested content."];
            return NO;
		}
	}
    
	int ncDataCodeWord = CS_QRE_VersionInfo[m_nVersion].ncDataCodeWord[level];
    
	int ncTerminater = (ncDataCodeWord * 8) - m_ncDataCodeWordBit;
    if (ncTerminater > 4) {
        ncTerminater = 4;
    }
    
	if (ncTerminater > 0)
		m_ncDataCodeWordBit = [self setBitStreamWIthIndex:m_ncDataCodeWordBit andData:0 andLenData:ncTerminater];
    
    
	unsigned char byPaddingCode = 0xec;
    
	for (i = (m_ncDataCodeWordBit + 7) / 8; i < ncDataCodeWord; ++i)
	{
		m_byDataCodeWord[i] = byPaddingCode;
        
		byPaddingCode = (unsigned char)(byPaddingCode == 0xec ? 0x11 : 0xec);
	}
    
	m_ncAllCodeWord = CS_QRE_VersionInfo[m_nVersion].ncAllCodeWord;
    memset(m_byAllCodeWord, 0, m_ncAllCodeWord);
    
	int nDataCwIndex = 0;
    
    int ncBlock1 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo1[level].ncRSBlock;
	int ncBlock2 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo2[level].ncRSBlock;
	int ncBlockSum = ncBlock1 + ncBlock2;
    
	int nBlockNo = 0;
    
	int ncDataCw1 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo1[level].ncDataCodeWord;
	int ncDataCw2 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo2[level].ncDataCodeWord;
    
	for (i = 0; i < ncBlock1; ++i)
	{
		for (j = 0; j < ncDataCw1; ++j)
		{
			m_byAllCodeWord[(ncBlockSum * j) + nBlockNo] = m_byDataCodeWord[nDataCwIndex++];
		}
        
		++nBlockNo;
	}
    
	for (i = 0; i < ncBlock2; ++i)
	{
		for (j = 0; j < ncDataCw2; ++j)
		{
			if (j < ncDataCw1)
			{
				m_byAllCodeWord[(ncBlockSum * j) + nBlockNo] = m_byDataCodeWord[nDataCwIndex++];
			}
			else
			{
				m_byAllCodeWord[(ncBlockSum * ncDataCw1) + i]  = m_byDataCodeWord[nDataCwIndex++];
			}
		}
        
		++nBlockNo;
	}
    
	int ncRSCw1 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo1[level].ncAllCodeWord - ncDataCw1;
	int ncRSCw2 = CS_QRE_VersionInfo[m_nVersion].RS_BlockInfo2[level].ncAllCodeWord - ncDataCw2;
    
	nDataCwIndex = 0;
	nBlockNo = 0;
    
	for (i = 0; i < ncBlock1; ++i)
	{
        memset(m_byRSWork, 0, sizeof(m_byRSWork));
		memmove(m_byRSWork, m_byDataCodeWord + nDataCwIndex, ncDataCw1);
        
        [self getRSCodeWord:m_byRSWork withNumData:ncDataCw1 andNumCode:ncRSCw1];
        
		for (j = 0; j < ncRSCw1; ++j)
		{
			m_byAllCodeWord[ncDataCodeWord + (ncBlockSum * j) + nBlockNo] = m_byRSWork[j];
		}
        
		nDataCwIndex += ncDataCw1;
		++nBlockNo;
	}
    
	for (i = 0; i < ncBlock2; ++i)
	{
        memset(m_byRSWork, 0, sizeof(m_byRSWork));
		memmove(m_byRSWork, m_byDataCodeWord + nDataCwIndex, ncDataCw2);
        
        [self getRSCodeWord:m_byRSWork withNumData:ncDataCw2 andNumCode:ncRSCw2];
        
		for (j = 0; j < ncRSCw2; ++j)
		{
			m_byAllCodeWord[ncDataCodeWord + (ncBlockSum * j) + nBlockNo] = m_byRSWork[j];
		}
        
		nDataCwIndex += ncDataCw2;
		++nBlockNo;
	}
    
	m_nSymbleSize = m_nVersion * 4 + 17;
    
    [self formatModule];
	return YES;
}

/*
 *  No description
 */
-(void) setFinderPatternWithX:(int) x andY:(int) y
{
	static unsigned char byPattern[] = {
        0x7f,  // 1111111b
        0x41,  // 1000001b
        0x5d,  // 1011101b
        0x5d,  // 1011101b
        0x5d,  // 1011101b
        0x41,  // 1000001b
        0x7f}; // 1111111b
	int i, j;
    
	for (i = 0; i < 7; ++i)
	{
		for (j = 0; j < 7; ++j)
		{
			m_byModuleData[x + j][y + i] = (byPattern[i] & (1 << (6 - j))) ? '\x30' : '\x20';
		}
	}
}

/*
 *  Deployment version information pattern (model number)
 */
-(void) setVersionPattern
{
	int i, j;
    
	if (m_nVersion <= 6)
		return;
    
	int nVerData = m_nVersion << 12;
    
	for (i = 0; i < 6; ++i)
	{
		if (nVerData & (1 << (17 - i)))
		{
			nVerData ^= (0x1f25 << (5 - i));
		}
	}
    
	nVerData += m_nVersion << 12;
    
	for (i = 0; i < 6; ++i)
	{
		for (j = 0; j < 3; ++j)
		{
			m_byModuleData[m_nSymbleSize - 11 + j][i] = m_byModuleData[i][m_nSymbleSize - 11 + j] =
			(nVerData & (1 << (i * 3 + j))) ? '\x30' : '\x20';
		}
	}
}

/*
 *  No description
 */
-(void) setAlignmentPatternWithX:(int) x andY:(int) y
{
	static unsigned char byPattern[] = {
        0x1f,  // 11111b
        0x11,  // 10001b
        0x15,  // 10101b
        0x11,  // 10001b
        0x1f}; // 11111b
	int i, j;
    
	if (m_byModuleData[x][y] & 0x20)
		return;
    
	x -= 2; y -= 2;
    
	for (i = 0; i < 5; ++i)
	{
		for (j = 0; j < 5; ++j)
		{
			m_byModuleData[x + j][y + i] = (byPattern[i] & (1 << (4 - j))) ? '\x30' : '\x20';
		}
	}
}


/*
 *  Function module placement.
 */
-(void) setFunctionModule
{
	int i, j;
    
    [self setFinderPatternWithX:0 andY:0];
    [self setFinderPatternWithX:m_nSymbleSize - 7 andY:0];
    [self setFinderPatternWithX:0 andY:m_nSymbleSize - 7];
    
	for (i = 0; i < 8; ++i)
	{
		m_byModuleData[i][7] = m_byModuleData[7][i] = '\x20';
		m_byModuleData[m_nSymbleSize - 8][i] = m_byModuleData[m_nSymbleSize - 8 + i][7] = '\x20';
		m_byModuleData[i][m_nSymbleSize - 8] = m_byModuleData[7][m_nSymbleSize - 8 + i] = '\x20';
	}
    
	for (i = 0; i < 9; ++i)
	{
		m_byModuleData[i][8] = m_byModuleData[8][i] = '\x20';
	}
    
	for (i = 0; i < 8; ++i)
	{
		m_byModuleData[m_nSymbleSize - 8 + i][8] = m_byModuleData[8][m_nSymbleSize - 8 + i] = '\x20';
	}
    
    [self setVersionPattern];
    
	for (i = 0; i < CS_QRE_VersionInfo[m_nVersion].ncAlignPoint; ++i)
	{
        [self setAlignmentPatternWithX:CS_QRE_VersionInfo[m_nVersion].nAlignPoint[i] andY:6];
        [self setAlignmentPatternWithX:6 andY:CS_QRE_VersionInfo[m_nVersion].nAlignPoint[i]];
        
		for (j = 0; j < CS_QRE_VersionInfo[m_nVersion].ncAlignPoint; ++j)
		{
            [self setAlignmentPatternWithX:CS_QRE_VersionInfo[m_nVersion].nAlignPoint[i] andY:CS_QRE_VersionInfo[m_nVersion].nAlignPoint[j]];
		}
	}
    
	for (i = 8; i <= m_nSymbleSize - 9; ++i)
	{
		m_byModuleData[i][6] = (i % 2) == 0 ? '\x30' : '\x20';
		m_byModuleData[6][i] = (i % 2) == 0 ? '\x30' : '\x20';
	}
}

/*
 *  Data placement pattern
 */
-(void) setCodeWordPattern
{
	int x = m_nSymbleSize;
	int y = m_nSymbleSize - 1;
    
	int nCoef_x = 1;
	int nCoef_y = 1;
    
	int i, j;
    
	for (i = 0; i < m_ncAllCodeWord; ++i)
	{
		for (j = 0; j < 8; ++j)
		{
			do
			{
				x += nCoef_x;
				nCoef_x *= -1;
                
				if (nCoef_x < 0)
				{
					y += nCoef_y;
                    
					if (y < 0 || y == m_nSymbleSize)
					{
						y = (y < 0) ? 0 : m_nSymbleSize - 1;
						nCoef_y *= -1;
                        
						x -= 2;
                        
						if (x == 6)
							--x;
					}
				}
			}
			while (m_byModuleData[x][y] & 0x20);
            
			m_byModuleData[x][y] = (m_byAllCodeWord[i] & (1 << (7 - j))) ? '\x02' : '\x00';
		}
	}
}

/*
 *  Masking pattern arrangement
 */
-(void) setMaskingPatternWithNumber:(int) nPatternNo
{
	int i, j;
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize; ++j)
		{
			if (! (m_byModuleData[j][i] & 0x20))
			{
				unsigned char bMask;
                
				switch (nPatternNo)
				{
                    case 0:
                        bMask = ((i + j) % 2 == 0);
                        break;
                        
                    case 1:
                        bMask = (i % 2 == 0);
                        break;
                        
                    case 2:
                        bMask = (j % 3 == 0);
                        break;
                        
                    case 3:
                        bMask = ((i + j) % 3 == 0);
                        break;
                        
                    case 4:
                        bMask = (((i / 2) + (j / 3)) % 2 == 0);
                        break;
                        
                    case 5:
                        bMask = (((i * j) % 2) + ((i * j) % 3) == 0);
                        break;
                        
                    case 6:
                        bMask = ((((i * j) % 2) + ((i * j) % 3)) % 2 == 0);
                        break;
                        
                    default: // case 7:
                        bMask = ((((i * j) % 3) + ((i + j) % 2)) % 2 == 0);
                        break;
				}
                
				m_byModuleData[j][i] = (unsigned char)((m_byModuleData[j][i] & 0xfe) | (((m_byModuleData[j][i] & 0x02) > 1) ^ bMask));
			}
		}
	}
}

/*
 *  Arrangement of format information.
 */
-(void) setFormatInfoPatternWithNumber:(int) nPatternNo
{
	int nFormatInfo;
	int i;
    
	switch (m_nLevel)
	{
        case CS_QRE_EC_MED:
            nFormatInfo = 0x00; // 00nnnb
            break;
            
        case CS_QRE_EC_LOW:
            nFormatInfo = 0x08; // 01nnnb
            break;
            
        case CS_QRE_EC_QUT:
            nFormatInfo = 0x18; // 11nnnb
            break;
            
        default: // case RSI_QR_EC_HI:
            nFormatInfo = 0x10; // 10nnnb
            break;
	}
    
	nFormatInfo += nPatternNo;
    
	int nFormatData = nFormatInfo << 10;
    
	for (i = 0; i < 5; ++i)
	{
		if (nFormatData & (1 << (14 - i)))
		{
			nFormatData ^= (0x0537 << (4 - i)); // 10100110111b
		}
	}
    
	nFormatData += nFormatInfo << 10;
    
	nFormatData ^= 0x5412; // 101010000010010b
    
	for (i = 0; i <= 5; ++i)
		m_byModuleData[8][i] = (nFormatData & (1 << i)) ? '\x30' : '\x20';
    
	m_byModuleData[8][7] = (nFormatData & (1 << 6)) ? '\x30' : '\x20';
	m_byModuleData[8][8] = (nFormatData & (1 << 7)) ? '\x30' : '\x20';
	m_byModuleData[7][8] = (nFormatData & (1 << 8)) ? '\x30' : '\x20';
    
	for (i = 9; i <= 14; ++i)
		m_byModuleData[14 - i][8] = (nFormatData & (1 << i)) ? '\x30' : '\x20';
    
	for (i = 0; i <= 7; ++i)
		m_byModuleData[m_nSymbleSize - 1 - i][8] = (nFormatData & (1 << i)) ? '\x30' : '\x20';
    
	m_byModuleData[8][m_nSymbleSize - 8] = '\x30';
    
	for (i = 8; i <= 14; ++i)
		m_byModuleData[8][m_nSymbleSize - 15 + i] = (nFormatData & (1 << i)) ? '\x30' : '\x20';
}

/*
 *  Penalty score calculated after masking.
 */
-(int) countPenalty
{
	int nPenalty = 0;
	int i, j, k;
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize - 4; ++j)
		{
			int nCount = 1;
            
			for (k = j + 1; k < m_nSymbleSize; k++)
			{
				if (((m_byModuleData[i][j] & 0x11) == 0) == ((m_byModuleData[i][k] & 0x11) == 0))
					++nCount;
				else
					break;
			}
            
			if (nCount >= 5)
			{
				nPenalty += 3 + (nCount - 5);
			}
            
			j = k - 1;
		}
	}
    
    for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize - 4; ++j)
		{
			int nCount = 1;
            
			for (k = j + 1; k < m_nSymbleSize; k++)
			{
				if (((m_byModuleData[j][i] & 0x11) == 0) == ((m_byModuleData[k][i] & 0x11) == 0))
					++nCount;
				else
					break;
			}
            
			if (nCount >= 5)
			{
				nPenalty += 3 + (nCount - 5);
			}
            
			j = k - 1;
		}
	}
    
	for (i = 0; i < m_nSymbleSize - 1; ++i)
	{
		for (j = 0; j < m_nSymbleSize - 1; ++j)
		{
			if ((((m_byModuleData[i][j] & 0x11) == 0) == ((m_byModuleData[i + 1][j]		& 0x11) == 0)) &&
				(((m_byModuleData[i][j] & 0x11) == 0) == ((m_byModuleData[i]	[j + 1] & 0x11) == 0)) &&
				(((m_byModuleData[i][j] & 0x11) == 0) == ((m_byModuleData[i + 1][j + 1] & 0x11) == 0)))
			{
				nPenalty += 3;
			}
		}
	}
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize - 6; ++j)
		{
			if (((j == 0) ||				 (! (m_byModuleData[i][j - 1] & 0x11))) &&
                (   m_byModuleData[i][j]     & 0x11)   &&
                (! (m_byModuleData[i][j + 1] & 0x11))  &&
                (   m_byModuleData[i][j + 2] & 0x11)   &&
                (   m_byModuleData[i][j + 3] & 0x11)   &&
                (   m_byModuleData[i][j + 4] & 0x11)   &&
                (! (m_byModuleData[i][j + 5] & 0x11))  &&
                (   m_byModuleData[i][j + 6] & 0x11)   &&
				((j == m_nSymbleSize - 7) || (! (m_byModuleData[i][j + 7] & 0x11))))
			{
				if (((j < 2 || ! (m_byModuleData[i][j - 2] & 0x11)) &&
					 (j < 3 || ! (m_byModuleData[i][j - 3] & 0x11)) &&
					 (j < 4 || ! (m_byModuleData[i][j - 4] & 0x11))) ||
					((j >= m_nSymbleSize - 8  || ! (m_byModuleData[i][j + 8]  & 0x11)) &&
					 (j >= m_nSymbleSize - 9  || ! (m_byModuleData[i][j + 9]  & 0x11)) &&
					 (j >= m_nSymbleSize - 10 || ! (m_byModuleData[i][j + 10] & 0x11))))
				{
					nPenalty += 40;
				}
			}
		}
	}
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize - 6; ++j)
		{
			if (((j == 0) ||				 (! (m_byModuleData[j - 1][i] & 0x11))) &&
                (   m_byModuleData[j]    [i] & 0x11)   &&
                (! (m_byModuleData[j + 1][i] & 0x11))  &&
                (   m_byModuleData[j + 2][i] & 0x11)   &&
                (   m_byModuleData[j + 3][i] & 0x11)   &&
                (   m_byModuleData[j + 4][i] & 0x11)   &&
                (! (m_byModuleData[j + 5][i] & 0x11))  &&
                (   m_byModuleData[j + 6][i] & 0x11)   &&
				((j == m_nSymbleSize - 7) || (! (m_byModuleData[j + 7][i] & 0x11))))
			{
				if (((j < 2 || ! (m_byModuleData[j - 2][i] & 0x11)) &&
					 (j < 3 || ! (m_byModuleData[j - 3][i] & 0x11)) &&
					 (j < 4 || ! (m_byModuleData[j - 4][i] & 0x11))) ||
					((j >= m_nSymbleSize - 8  || ! (m_byModuleData[j + 8][i]  & 0x11)) &&
					 (j >= m_nSymbleSize - 9  || ! (m_byModuleData[j + 9][i]  & 0x11)) &&
					 (j >= m_nSymbleSize - 10 || ! (m_byModuleData[j + 10][i] & 0x11))))
				{
					nPenalty += 40;
				}
			}
		}
	}
    
	int nCount = 0;
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize; ++j)
		{
			if (! (m_byModuleData[i][j] & 0x11))
			{
				++nCount;
			}
		}
	}
    
	nPenalty += (abs(50 - ((nCount * 100) / (m_nSymbleSize * m_nSymbleSize))) / 5) * 10;
    
	return nPenalty;
}

/*
 *  Data placement to the module
 */
-(void) formatModule
{
	int i, j;
    
    memset(m_byModuleData, 0, sizeof(m_byModuleData));
    
    [self setFunctionModule];
    
    [self setCodeWordPattern];
    
	if (m_nMaskingNo == -1)
	{
		m_nMaskingNo = 0;
        
        [self setMaskingPatternWithNumber:m_nMaskingNo];
        
        [self setFormatInfoPatternWithNumber:m_nMaskingNo];
        
		int nMinPenalty = [self countPenalty];
        
		for (i = 1; i <= 7; ++i)
		{
            [self setMaskingPatternWithNumber:i];
            [self setFormatInfoPatternWithNumber:i];
            
			int nPenalty = [self countPenalty];
            
			if (nPenalty < nMinPenalty)
			{
				nMinPenalty = nPenalty;
				m_nMaskingNo = i;
			}
		}
	}
    
    [self setMaskingPatternWithNumber:m_nMaskingNo];
    [self setFormatInfoPatternWithNumber:m_nMaskingNo];
    
	for (i = 0; i < m_nSymbleSize; ++i)
	{
		for (j = 0; j < m_nSymbleSize; ++j)
		{
			m_byModuleData[i][j] = (unsigned char)((m_byModuleData[i][j] & 0x11) != 0);
		}
	}
}

@end
