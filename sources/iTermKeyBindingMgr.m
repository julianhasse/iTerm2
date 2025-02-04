/*
 **  iTermKeyBindingMgr.m
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Setlur
 **
 **  Project: iTerm
 **
 **  Description: implements the key binding manager.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
// The remapModifiers function has code with this license:
/*
 * Copyright (c) 2009, 2010 <andrew iain mcdermott via gmail>
 *
 * Source can be cloned from:
 *
 *  git://github.com/aim-stuff/cmd-key-happy.git
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
/*
 * Note: xterm reports new escape codes for modifiers like Shift + any key,
 * like, for instance, the cursor keys as of 2006.
 *
 * Excerpt from terminfo:
 *  kLFT=\E[1;2D,
 *  kRIT=\E[1;2C,
 *  ...
 *
 * Also, the default setting of the xterm setting "modifyCursorKeys"
 * changed to "2" which will generate these new escape codes.
 * The old ones can be seen by setting it to zero, although they are
 * obsolete.
 *
 * Please check with "infocmp -L xterm" and "read", if anything behaves
 * weird in iTerm2 and the reported escape code is wrong.
 *
 * For checking the escape codes, run "read" (a shell builtin) and press
 * the key combination you want to know the code of, like, Shift + Arrow
 * Left.
 */

#import "ITAddressBookMgr.h"

#import "DebugLogging.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermHotKeyController.h"
#import "iTermKeyBindingMgr.h"
#import "iTermModifierRemapper.h"
#import "iTermPasteSpecialViewController.h"
#import "iTermPreferences.h"
#import "NSArray+iTerm.h"
#import "NSStringITerm.h"
#import "PTYTextView.h"   // For selection movement units
#import <Carbon/Carbon.h>

static NSDictionary *globalKeyMap;
static NSDictionary *globalTouchBarMap;
static NSString *const kFactoryDefaultsGlobalPreset = @"Factory Defaults";
NSString *const iTermKeyBindingDictionaryKeyAction = @"Action";
NSString *const iTermKeyBindingDictionaryKeyParameter = @"Text";
NSString *const iTermKeyBindingDictionaryKeyLabel = @"Label";

@implementation iTermKeyBindingMgr

+ (NSString *)stringForCharacter:(unsigned int)character isArrow:(BOOL *)isArrowPtr {
    BOOL isArrow = NO;
    NSString *aString = nil;
    switch (character) {
        case NSDownArrowFunctionKey:
            aString = @"↓";
            isArrow = YES;
            break;
        case NSLeftArrowFunctionKey:
            aString = @"←";
            isArrow = YES;
            break;
        case NSRightArrowFunctionKey:
            aString =@"→";
            isArrow = YES;
            break;
        case NSUpArrowFunctionKey:
            aString = @"↑";
            isArrow = YES;
            break;
        case NSDeleteFunctionKey:
            aString = NSLocalizedStringFromTableInBundle(@"Del→",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass:[self class]],
                                                         @"Key Names");
            break;
        case 0x7f:
            aString = NSLocalizedStringFromTableInBundle(@"←Delete",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass:[self class]],
                                                         @"Key Names");
            break;
        case NSEndFunctionKey:
            aString = NSLocalizedStringFromTableInBundle(@"End",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass:[self class]],
                                                         @"Key Names");
            break;
        case NSF1FunctionKey:
        case NSF2FunctionKey:
        case NSF3FunctionKey:
        case NSF4FunctionKey:
        case NSF5FunctionKey:
        case NSF6FunctionKey:
        case NSF7FunctionKey:
        case NSF8FunctionKey:
        case NSF9FunctionKey:
        case NSF10FunctionKey:
        case NSF11FunctionKey:
        case NSF12FunctionKey:
        case NSF13FunctionKey:
        case NSF14FunctionKey:
        case NSF15FunctionKey:
        case NSF16FunctionKey:
        case NSF17FunctionKey:
        case NSF18FunctionKey:
        case NSF19FunctionKey:
        case NSF20FunctionKey:
            aString = [NSString stringWithFormat: @"F%d", (character - NSF1FunctionKey + 1)];
            break;
        case NSHelpFunctionKey:
            aString = NSLocalizedStringFromTableInBundle(@"Help",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass:[self class]],
                                                         @"Key Names");
            break;
        case NSHomeFunctionKey:
            aString = NSLocalizedStringFromTableInBundle(@"Home",
                                                         @"iTerm",
                                                         [NSBundle bundleForClass:[self class]],
                                                         @"Key Names");
            break;

        // These are standard on Apple en_GB keyboards where ~ and ` go on US keyboards (between esc
        // and tab).
        case 0xa7:
            aString = @"§";
            break;
        case 0xb1: // shifted version of above.
            aString = @"±";
            break;

        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            aString = [NSString stringWithFormat: @"%d", (character - '0')];
            break;
        case '=':
            aString = @"=";
            break;
        case '/':
            aString = @"/";
            break;
        case '*':
            aString = @"*";
            break;
        case '-':
            aString = @"-";
            break;
        case '+':
            aString = @"+";
            break;
        case '.':
            aString = @".";
            break;
        case NSClearLineFunctionKey:
            aString = @"Numlock";
            break;
        case NSPageDownFunctionKey:
            aString = @"Page Down";
            break;
        case NSPageUpFunctionKey:
            aString = @"Page Up";
            break;
        case 0x3: // 'enter' on numeric key pad
            aString = @"↩";
            break;
        case NSInsertFunctionKey:  // Fall through
        case NSInsertCharFunctionKey:
            aString = @"Insert";
            break;

        default:
            if (character > ' ' && (character < 0xe800 || character > 0xfdff) && character < 0xffff) {
                aString = [NSString stringWithFormat:@"%C", (unichar)character];
            } else {
                switch (character) {
                    case ' ':
                        aString = @"Space";
                        break;

                    case '\r':
                        aString = @"Return ↩";
                        break;

                    case 27:
                        aString = @"Esc ⎋";
                        break;

                    case '\t':
                        aString = @"Tab ↦";
                        break;

                    case 0x19:
                        // back-tab
                        aString = @"Tab ↤";
                        break;

                    default:
                        aString = [NSString stringWithFormat: @"Hex Code 0x%x", character];
                        break;
                }
            }
            break;
    }
    if (isArrowPtr) {
        *isArrowPtr = isArrow;
    }
    return aString;
}

+ (NSString *)stringForKeyCode:(CGKeyCode)virtualKeyCode
                     character:(unichar)character
                       isArrow:(BOOL *)isArrow {
    TISInputSourceRef inputSource = NULL;
    NSString *result = nil;

    if (virtualKeyCode != 0) {
        inputSource = TISCopyCurrentKeyboardInputSource();
        if (inputSource == NULL) {
            goto exit;
        }

        CFDataRef keyLayoutData = TISGetInputSourceProperty(inputSource,
                                                            kTISPropertyUnicodeKeyLayoutData);
        if (keyLayoutData == NULL) {
            goto exit;
        }

        const UCKeyboardLayout *keyLayoutPtr = (const UCKeyboardLayout *)CFDataGetBytePtr(keyLayoutData);
        if (keyLayoutPtr == NULL) {
            goto exit;
        }

        UInt32 deadKeyState = 0;
        UniChar unicodeString[4];
        UniCharCount actualStringLength;

        OSStatus status = UCKeyTranslate(keyLayoutPtr,
                                         virtualKeyCode,
                                         kUCKeyActionDisplay,
                                         0,
                                         LMGetKbdType(),
                                         kUCKeyTranslateNoDeadKeysBit,
                                         &deadKeyState,
                                         sizeof(unicodeString) / sizeof(*unicodeString),
                                         &actualStringLength,
                                         unicodeString);
        if (status != noErr) {
            goto exit;
        }

        if (actualStringLength == 0) {
            goto exit;
        }

        if (unicodeString[0] <= ' ' || unicodeString[0] == 127) {
            goto exit;
        }

        result = [NSString stringWithCharacters:unicodeString length:actualStringLength];
    }

exit:
    if (inputSource != NULL) {
        CFRelease(inputSource);
    }
    if (result == nil) {
        result = [self stringForCharacter:character isArrow:isArrow];
    }
    return result;
}

+ (NSString *)formatKeyCombination:(NSString *)theKeyCombination {
    return [self formatKeyCombination:theKeyCombination keyCode:0];
}

+ (NSString *)formatKeyCombination:(NSString *)theKeyCombination keyCode:(NSUInteger)virtualKeyCode {
    unsigned int keyMods = 0;
    unsigned int keyCode = 0;

    sscanf([theKeyCombination UTF8String], "%x-%x", &keyCode, &keyMods);

    BOOL isArrow = NO;
    NSString *charactersAsString = [self stringForKeyCode:virtualKeyCode character:keyCode isArrow:&isArrow];

    NSMutableString *result = [[[NSString stringForModifiersWithMask:keyMods] mutableCopy] autorelease];
    if ((keyMods & NSEventModifierFlagNumericPad) && !isArrow) {
        [result appendString: @"num-"];
    }
    [result appendString:charactersAsString];
    return result;
}

+ (NSString*)_bookmarkNameForGuid:(NSString*)guid
{
    return [[[ProfileModel sharedInstance] bookmarkWithGuid:guid] objectForKey:KEY_NAME];
}

+ (NSString *)touchBarLabelForBinding:(NSDictionary *)binding {
    return binding[iTermKeyBindingDictionaryKeyLabel] ?: @"?";
}

+ (NSString *)formatAction:(NSDictionary *)keyInfo
{
    NSString *actionString;
    int action;
    NSString *auxText;

    action = [[keyInfo objectForKey:iTermKeyBindingDictionaryKeyAction] intValue];
    auxText = [keyInfo objectForKey:iTermKeyBindingDictionaryKeyParameter];

    switch (action) {
        case KEY_ACTION_MOVE_TAB_LEFT:
            actionString = @"Move Tab Left";
            break;
        case KEY_ACTION_MOVE_TAB_RIGHT:
            actionString = @"Move Tab Right";
            break;
        case KEY_ACTION_NEXT_MRU_TAB:
            actionString = @"Cycle Tabs Forward";
            break;
        case KEY_ACTION_PREVIOUS_MRU_TAB:
            actionString = @"Cycle Tabs Backward";
            break;
        case KEY_ACTION_NEXT_PANE:
            actionString = @"Next Pane";
            break;
        case KEY_ACTION_PREVIOUS_PANE:
            actionString = @"Previous Pane";
            break;
        case KEY_ACTION_NEXT_SESSION:
            actionString = @"Next Tab";
            break;
        case KEY_ACTION_NEXT_WINDOW:
            actionString = @"Next Window";
            break;
        case KEY_ACTION_PREVIOUS_SESSION:
            actionString = @"Previous Tab";
            break;
        case KEY_ACTION_PREVIOUS_WINDOW:
            actionString = @"Previous Window";
            break;
        case KEY_ACTION_SCROLL_END:
            actionString = @"Scroll To End";
            break;
        case KEY_ACTION_SCROLL_HOME:
            actionString = @"Scroll To Top";
            break;
        case KEY_ACTION_SCROLL_LINE_DOWN:
            actionString = @"Scroll One Line Down";
            break;
        case KEY_ACTION_SCROLL_LINE_UP:
            actionString = @"Scroll One Line Up";
            break;
        case KEY_ACTION_SCROLL_PAGE_DOWN:
            actionString = @"Scroll One Page Down";
            break;
        case KEY_ACTION_SCROLL_PAGE_UP:
            actionString = @"Scroll One Page Up";
            break;
        case KEY_ACTION_ESCAPE_SEQUENCE:
            actionString = [NSString stringWithFormat:@"%@ %@", @"Send ^[", auxText];
            break;
        case KEY_ACTION_HEX_CODE:
            actionString = [NSString stringWithFormat: @"%@ %@", @"Send Hex Codes:", auxText];
            break;
        case KEY_ACTION_VIM_TEXT:
            actionString = [NSString stringWithFormat:@"%@ \"%@\"", @"Send:", auxText];
            break;
        case KEY_ACTION_TEXT:
            actionString = [NSString stringWithFormat:@"%@ \"%@\"", @"Send:", auxText];
            break;
        case KEY_ACTION_RUN_COPROCESS:
            actionString = [NSString stringWithFormat:@"Run Coprocess \"%@\"",
						    auxText];
            break;
        case KEY_ACTION_SELECT_MENU_ITEM:
            actionString = [NSString stringWithFormat:@"%@ \"%@\"", @"Select Menu Item", auxText];
            break;
        case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
            actionString = [NSString stringWithFormat:@"New Window with \"%@\" Profile", [self _bookmarkNameForGuid:auxText]];
            break;
        case KEY_ACTION_NEW_TAB_WITH_PROFILE:
            actionString = [NSString stringWithFormat:@"New Tab with \"%@\" Profile", [self _bookmarkNameForGuid:auxText]];
            break;
        case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
            actionString = [NSString stringWithFormat:@"Split Horizontally with \"%@\" Profile", [self _bookmarkNameForGuid:auxText]];
            break;
        case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
            actionString = [NSString stringWithFormat:@"Split Vertically with \"%@\" Profile", [self _bookmarkNameForGuid:auxText]];
            break;
        case KEY_ACTION_SET_PROFILE:
            actionString = [NSString stringWithFormat:@"Change Profile to \"%@\"", [self _bookmarkNameForGuid:auxText]];
            break;
        case KEY_ACTION_LOAD_COLOR_PRESET:
            actionString = [NSString stringWithFormat:@"Load Color Preset \"%@\"", auxText];
            break;
        case KEY_ACTION_SEND_C_H_BACKSPACE:
            actionString = @"Send ^H Backspace";
            break;
        case KEY_ACTION_SEND_C_QM_BACKSPACE:
            actionString = @"Send ^? Backspace";
            break;
        case KEY_ACTION_IGNORE:
            actionString = @"Ignore";
            break;
        case KEY_ACTION_IR_FORWARD:
            actionString = @"Unsupported Command";
            break;
        case KEY_ACTION_IR_BACKWARD:
            actionString = @"Start Instant Replay";
            break;
        case KEY_ACTION_SELECT_PANE_LEFT:
            actionString = @"Select Split Pane on Left";
            break;
        case KEY_ACTION_SELECT_PANE_RIGHT:
            actionString = @"Select Split Pane on Right";
            break;
        case KEY_ACTION_SELECT_PANE_ABOVE:
            actionString = @"Select Split Pane Above";
            break;
        case KEY_ACTION_SELECT_PANE_BELOW:
            actionString = @"Select Split Pane Below";
            break;
        case KEY_ACTION_DO_NOT_REMAP_MODIFIERS:
            actionString = @"Do Not Remap Modifiers";
            break;
        case KEY_ACTION_REMAP_LOCALLY:
            actionString = @"Remap Modifiers in iTerm2 Only";
            break;
        case KEY_ACTION_TOGGLE_FULLSCREEN:
            actionString = @"Toggle Fullscreen";
            break;
        case KEY_ACTION_TOGGLE_HOTKEY_WINDOW_PINNING:
            actionString = @"Toggle Pin Hotkey Window";
            break;
        case KEY_ACTION_UNDO:
            actionString = @"Undo";
            break;
        case KEY_ACTION_FIND_REGEX:
            actionString = [NSString stringWithFormat:@"Find Regex “%@”", auxText];
            break;
        case KEY_FIND_AGAIN_DOWN:
            actionString = @"Find Again Down";
            break;
        case KEY_FIND_AGAIN_UP:
            actionString = @"Find Again Up";
            break;
        case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION: {
            NSString *pasteDetails =
                [iTermPasteSpecialViewController descriptionForCodedSettings:auxText];
            if (pasteDetails.length) {
                actionString = [NSString stringWithFormat:@"Paste from Selection: %@", pasteDetails];
            } else {
                actionString = @"Paste from Selection";
            }
            break;
        }
        case KEY_ACTION_PASTE_SPECIAL: {
            NSString *pasteDetails =
                [iTermPasteSpecialViewController descriptionForCodedSettings:auxText];
            if (pasteDetails.length) {
                actionString = [NSString stringWithFormat:@"Paste: %@", pasteDetails];
            } else {
                actionString = @"Paste";
            }
            break;
        }
        case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
            actionString = [NSString stringWithFormat:@"Move End of Selection Left %@",
                            [self stringForSelectionMovementUnit:auxText.integerValue]];
            break;
        case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
            actionString = [NSString stringWithFormat:@"Move End of Selection Right %@",
                            [self stringForSelectionMovementUnit:auxText.integerValue]];
            break;
        case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
            actionString = [NSString stringWithFormat:@"Move Start of Selection Left %@",
                            [self stringForSelectionMovementUnit:auxText.integerValue]];
            break;
        case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
            actionString = [NSString stringWithFormat:@"Move Start of Selection Right %@",
                            [self stringForSelectionMovementUnit:auxText.integerValue]];
            break;

        case KEY_ACTION_DECREASE_HEIGHT:
            actionString = @"Decrease Height";
            break;
        case KEY_ACTION_INCREASE_HEIGHT:
            actionString = @"Increase Height";
            break;

        case KEY_ACTION_DECREASE_WIDTH:
            actionString = @"Decrease Width";
            break;
        case KEY_ACTION_INCREASE_WIDTH:
            actionString = @"Increase Width";
            break;

        case KEY_ACTION_SWAP_PANE_LEFT:
            actionString = @"Swap With Split Pane on Left";
            break;
        case KEY_ACTION_SWAP_PANE_RIGHT:
            actionString = @"Swap With Split Pane on Right";
            break;
        case KEY_ACTION_SWAP_PANE_ABOVE:
            actionString = @"Swap With Split Pane Above";
            break;
        case KEY_ACTION_SWAP_PANE_BELOW:
            actionString = @"Swap With Split Pane Below";
            break;
        case KEY_ACTION_TOGGLE_MOUSE_REPORTING:
            actionString = @"Toggle Mouse Reporting";
            break;
        case KEY_ACTION_INVOKE_SCRIPT_FUNCTION:
            actionString = [NSString stringWithFormat:@"Call %@", auxText];
            break;
        case KEY_ACTION_DUPLICATE_TAB:
            actionString = @"Duplicate Tab";
            break;
        default:
            actionString = [NSString stringWithFormat: @"%@ %d", @"Unknown Action ID", action];
            break;
        case KEY_ACTION_MOVE_TO_SPLIT_PANE:
            actionString = @"Move to Split Pane";
            break;
    }

    return actionString;
}

+ (NSString *)stringForSelectionMovementUnit:(PTYTextViewSelectionExtensionUnit)unit {
    switch (unit) {
        case kPTYTextViewSelectionExtensionUnitLine:
            return @"By Line";
        case kPTYTextViewSelectionExtensionUnitCharacter:
            return @"By Character";
        case kPTYTextViewSelectionExtensionUnitWord:
            return @"By Word";
        case kPTYTextViewSelectionExtensionUnitMark:
            return @"By Mark";
    }
    XLog(@"Unrecognized selection movement unit %@", @(unit));
    return @"";
}

+ (BOOL)haveGlobalKeyMappingForKeyString:(NSString*)keyString
{
    return [[self globalKeyMap] objectForKey:keyString] != nil;
}

+ (BOOL)haveKeyMappingForKeyString:(NSString*)keyString inBookmark:(Profile*)bookmark {
    NSDictionary *dict = [bookmark objectForKey:KEY_KEYBOARD_MAP];
    return [dict objectForKey:keyString] != nil;
}

+ (NSEventModifierFlags)modifiersForKeyCode:(int)keyCode modifiers:(NSEventModifierFlags)keyMods {
    NSEventModifierFlags theModifiers = keyMods & (NSEventModifierFlagOption | NSEventModifierFlagControl | NSEventModifierFlagShift | NSEventModifierFlagCommand | NSEventModifierFlagNumericPad);

    // on some keyboards, arrow keys have NSEventModifierFlagNumericPad bit set; manually set it for keyboards that don't
    if (keyCode >= NSUpArrowFunctionKey && keyCode <= NSRightArrowFunctionKey) {
        theModifiers |= NSEventModifierFlagNumericPad;
    }
    return theModifiers;
}

+ (NSString *)identifierForCharacterIgnoringModifiers:(unichar)characterIgnoringModifiers
                                            modifiers:(NSEventModifierFlags)keyMods {
    // turn off all the other modifier bits we don't care about
    unsigned int theModifiers = [self modifiersForKeyCode:characterIgnoringModifiers modifiers:keyMods];
    return [NSString stringWithFormat: @"0x%x-0x%x", characterIgnoringModifiers, theModifiers];
}

+ (NSArray<iTermTuple<NSString *, NSDictionary *> *> *)tuplesInAllPresets {
    NSMutableArray<iTermTuple<NSString *, NSDictionary *> *> *result = [NSMutableArray array];

    NSDictionary *builtins = [iTermKeyBindingMgr builtInPresetKeyMappings];
    for (NSString *name in builtins) {
        NSDictionary<NSString *, NSDictionary *> *dict = builtins[name];
        [dict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull combo, NSDictionary * _Nonnull mapping, BOOL * _Nonnull stop) {
            [result addObject:[iTermTuple tupleWithObject:combo andObject:mapping]];
        }];
    }
    return result;
}

+ (NSArray<iTermTriple<NSString *, NSDictionary *, NSNumber *> *> *)triplesOfIdentifiersAndMappingsInProfile:(Profile *)profile {
    NSMutableArray<iTermTriple<NSString *, NSDictionary *, NSNumber *> *> *result = [NSMutableArray array];
    NSDictionary<NSString *, NSDictionary *> *keyboardMap = profile[KEY_KEYBOARD_MAP];
    [keyboardMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull mapping, BOOL * _Nonnull stop) {
        [result addObject:[iTermTriple tripleWithObject:key andObject:mapping object:@NO]];
    }];

    NSDictionary<NSString *, NSDictionary *> *touchbarMap = profile[KEY_TOUCHBAR_MAP];
    [touchbarMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull mapping, BOOL * _Nonnull stop) {
        [result addObject:[iTermTriple tripleWithObject:key andObject:mapping object:@YES]];
    }];
    return result;
}

+ (int)localActionForKeyCode:(unichar)keyCode
                   modifiers:(unsigned int)keyMods
                        text:(NSString **)text
                 keyMappings:(NSDictionary *)keyMappings
{
    NSString *keyString = [self identifierForCharacterIgnoringModifiers:keyCode modifiers:keyMods];

    NSDictionary *theKeyMapping;
    int retCode = -1;

    theKeyMapping = [keyMappings objectForKey: keyString];
    if (theKeyMapping == nil) {
        if (text) {
            *text = nil;
        }
        return -1;
    }

    // parse the mapping
    retCode = [[theKeyMapping objectForKey:iTermKeyBindingDictionaryKeyAction] intValue];
    if (text != nil) {
        *text = [theKeyMapping objectForKey:iTermKeyBindingDictionaryKeyParameter];
    }
    return retCode;
}

+ (void)_loadGlobalKeyMap {
    globalKeyMap = [[NSUserDefaults standardUserDefaults] objectForKey:@"GlobalKeyMap"];
    if (!globalKeyMap) {
        NSString* plistFile = [[NSBundle bundleForClass: [self class]] pathForResource:@"DefaultGlobalKeyMap" ofType:@"plist"];
        globalKeyMap = [NSDictionary dictionaryWithContentsOfFile:plistFile];
    }
    [globalKeyMap retain];
}

+ (void)loadGlobalTouchBarMap {
    globalTouchBarMap = [[NSUserDefaults standardUserDefaults] objectForKey:@"GlobalTouchBarMap"];
    if (!globalTouchBarMap) {
        NSString *plistFile = [[NSBundle bundleForClass: [self class]] pathForResource:@"DefaultGlobalTouchBarMap" ofType:@"plist"];
        globalTouchBarMap = [NSDictionary dictionaryWithContentsOfFile:plistFile];
    }
    [globalTouchBarMap retain];
}

+ (NSDictionary*)globalKeyMap {
    if (!globalKeyMap) {
        [iTermKeyBindingMgr _loadGlobalKeyMap];
    }
    return globalKeyMap;
}

+ (NSDictionary *)globalTouchBarMap {
    if (!globalTouchBarMap) {
        [iTermKeyBindingMgr loadGlobalTouchBarMap];
    }
    return globalTouchBarMap;
}

+ (void)setGlobalKeyMap:(NSDictionary *)src {
    [globalKeyMap autorelease];
    globalKeyMap = [src copy];
    [[NSUserDefaults standardUserDefaults] setObject:globalKeyMap forKey:@"GlobalKeyMap"];
}

+ (void)setGlobalTouchBarMap:(NSDictionary *)src {
    [globalTouchBarMap autorelease];
    globalTouchBarMap = [src copy];
    [[NSUserDefaults standardUserDefaults] setObject:globalTouchBarMap forKey:@"GlobalTouchBarMap"];
}

+ (int)actionForKeyCode:(unichar)keyCode
              modifiers:(unsigned int) keyMods
                   text:(NSString **) text
            keyMappings:(NSDictionary *)keyMappings
{
    int keyBindingAction = -1;
    if (keyMappings) {
        keyBindingAction = [iTermKeyBindingMgr localActionForKeyCode:keyCode
                                                           modifiers:keyMods
                                                                text:text
                                                         keyMappings:keyMappings];
    }
    if (keyMappings != [self globalKeyMap] && keyBindingAction < 0) {
        keyBindingAction = [iTermKeyBindingMgr localActionForKeyCode:keyCode
                                                           modifiers:keyMods
                                                                text:text
                                                         keyMappings:[self globalKeyMap]];
    }
    return keyBindingAction;
}

+ (int)actionForTouchBarItemBinding:(NSDictionary *)binding {
    return [binding[iTermKeyBindingDictionaryKeyAction] intValue];
}

+ (NSString *)parameterForTouchBarItemBinding:(NSDictionary *)binding {
    return binding[iTermKeyBindingDictionaryKeyParameter];
}

+ (NSMutableDictionary*)removeMappingAtIndex:(int)rowIndex inDictionary:(NSDictionary*)dict {
    NSMutableDictionary* km = [NSMutableDictionary dictionaryWithDictionary:dict];
    NSArray* allKeys = [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (rowIndex >= 0 && rowIndex < [allKeys count]) {
        [km removeObjectForKey:[allKeys objectAtIndex:rowIndex]];
    }
    return km;
}

+ (void)removeTouchBarItem:(NSString *)key {
    NSDictionary *dict = [self globalTouchBarMap];
    dict = [self dictionaryByRemovingTouchBarItem:key fromDictionary:dict];
    [self setGlobalTouchBarMap:dict];
}

+ (NSDictionary *)dictionaryByRemovingTouchBarItem:(NSString *)key fromDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *temp = [[dictionary mutableCopy] autorelease];
    [temp removeObjectForKey:key];
    return temp;
}


+ (void)removeMappingAtIndex:(int)rowIndex inBookmark:(NSMutableDictionary*)bookmark {
    [bookmark setObject:[iTermKeyBindingMgr removeMappingAtIndex:rowIndex
                                                    inDictionary:[bookmark objectForKey:KEY_KEYBOARD_MAP]]
                 forKey:KEY_KEYBOARD_MAP];
}

+ (void)removeTouchBarItemWithKey:(NSString *)key inMutableProfile:(MutableProfile *)profile {
    NSDictionary *map = profile[KEY_TOUCHBAR_MAP];
    map = [self dictionaryByRemovingTouchBarItem:key fromDictionary:map];
    profile[KEY_TOUCHBAR_MAP] = map;
}

+ (NSArray *)globalPresetNames {
    return @[ kFactoryDefaultsGlobalPreset ];
}

+ (void)setGlobalKeyMappingsToPreset:(NSString*)presetName
{
    assert([presetName isEqualToString:kFactoryDefaultsGlobalPreset]);
    if (globalKeyMap) {
        [globalKeyMap release];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"GlobalKeyMap"];
    }
    [self _loadGlobalKeyMap];
}

+ (NSDictionary*)readPresetKeyMappingsFromPlist:(NSString *)thePlist {
    NSString* plistFile = [[NSBundle bundleForClass:[self class]]
                            pathForResource:thePlist ofType:@"plist"];
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:plistFile];
    return dict;
}

+ (NSDictionary *)builtInPresetKeyMappings {
    return [self readPresetKeyMappingsFromPlist:@"PresetKeyMappings"];
}

+ (void)setKeyMappingsToPreset:(NSString*)presetName inBookmark:(NSMutableDictionary*)bookmark {
    NSMutableDictionary* km = [NSMutableDictionary dictionaryWithDictionary:[bookmark objectForKey:KEY_KEYBOARD_MAP]];

    [km removeAllObjects];
    NSDictionary* presetsDict = [self builtInPresetKeyMappings];

    NSDictionary* settings = [presetsDict objectForKey:presetName];
    [km setDictionary:settings];

    [bookmark setObject:km forKey:KEY_KEYBOARD_MAP];
}

+ (NSArray *)presetKeyMappingsNames {
    NSDictionary* presetsDict = [self builtInPresetKeyMappings];
    return [presetsDict allKeys];
}

+ (void)setMappingAtIndex:(int)rowIndex
                   forKey:(NSString*)keyString
                   action:(int)actionIndex
                    value:(NSString*)valueToSend
                createNew:(BOOL)newMapping
             inDictionary:(NSMutableDictionary*)km
{
    assert(keyString);
    NSString* origKeyCombo = nil;
    NSArray* allKeys =
        [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (!newMapping) {
        if (rowIndex >= 0 && rowIndex < [allKeys count]) {
            origKeyCombo = [allKeys objectAtIndex:rowIndex];
        } else {
            return;
        }
    } else if ([km objectForKey:keyString]) {
        // new mapping but same key combo as an existing one - overwrite it
        origKeyCombo = keyString;
    } else {
        // creating a new mapping and it doesn't collide with an existing one
        origKeyCombo = nil;
    }

    NSMutableDictionary* keyBinding =
        [[[NSMutableDictionary alloc] init] autorelease];
    [keyBinding setObject:[NSNumber numberWithInt:actionIndex]
                   forKey:iTermKeyBindingDictionaryKeyAction];
    [keyBinding setObject:[[valueToSend copy] autorelease] forKey:iTermKeyBindingDictionaryKeyParameter];
    if (origKeyCombo) {
        [km removeObjectForKey:origKeyCombo];
    }
    [km setObject:keyBinding forKey:keyString];
}

+ (void)setMappingAtIndex:(int)rowIndex
                   forKey:(NSString*)keyString
                   action:(int)actionIndex
                    value:(NSString*)valueToSend
                createNew:(BOOL)newMapping
               inBookmark:(NSMutableDictionary*)bookmark {
    NSMutableDictionary* km =
        [NSMutableDictionary dictionaryWithDictionary:[bookmark objectForKey:KEY_KEYBOARD_MAP]];
    [iTermKeyBindingMgr setMappingAtIndex:rowIndex forKey:keyString action:actionIndex value:valueToSend createNew:newMapping inDictionary:km];
    [bookmark setObject:km forKey:KEY_KEYBOARD_MAP];
}

+ (void)setTouchBarItemWithKey:(NSString *)key
                      toAction:(int)action
                         value:(NSString *)value
                         label:(NSString *)label
                     inProfile:(MutableProfile *)profile {
    NSMutableDictionary *map = [[profile[KEY_TOUCHBAR_MAP] mutableCopy] autorelease];
    if (!map) {
        map = [NSMutableDictionary dictionary];
    }
    [self updateDictionary:map forTouchBarItem:key action:action value:value label:label];
    profile[KEY_TOUCHBAR_MAP] = map;
}

+ (NSArray<NSString *> *)sortedTouchBarKeysInDictionary:(NSDictionary<NSString *, NSDictionary *> *)dict {
    NSArray<NSString *> *keys = dict.allKeys;
    keys = [keys sortedArrayUsingComparator:^NSComparisonResult(NSString *_Nonnull key1, NSString *_Nonnull key2) {
        NSString *desc1 = [self formatAction:dict[key1]];
        NSString *desc2 = [self formatAction:dict[key2]];
        return [desc1 compare:desc2];
    }];
    return keys;
}

+ (void)updateDictionary:(NSMutableDictionary *)dict
         forTouchBarItem:(NSString *)key
                  action:(int)action
                   value:(NSString *)parameter
                   label:(NSString *)label {
    NSMutableDictionary *binding = [NSMutableDictionary dictionary];
    binding[iTermKeyBindingDictionaryKeyAction] = @(action);
    if (parameter) {
        binding[iTermKeyBindingDictionaryKeyParameter] = parameter;
    }
    binding[iTermKeyBindingDictionaryKeyLabel] = label ?: @"?";
    dict[key] = binding;
}

+ (NSArray *)sortedGlobalKeyCombinations {
    NSDictionary* km = [self globalKeyMap];
    return [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

+ (NSArray *)sortedKeyCombinationsForProfile:(Profile *)profile {
    NSDictionary* km = profile[KEY_KEYBOARD_MAP];
    return [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

+ (NSArray *)sortedTouchBarItemsForProfile:(Profile *)profile {
    NSDictionary *map =profile[KEY_TOUCHBAR_MAP];
    return [self sortedTouchBarKeysInDictionary:map];
}

+ (NSString*)shortcutAtIndex:(int)rowIndex forBookmark:(Profile *)bookmark {
    NSDictionary* km = [bookmark objectForKey:KEY_KEYBOARD_MAP];
    NSArray* allKeys = [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (rowIndex >= 0 && rowIndex < [allKeys count]) {
        return [allKeys objectAtIndex:rowIndex];
    } else {
        return nil;
    }
}

+ (NSString*)globalShortcutAtIndex:(int)rowIndex
{
    NSDictionary* km = [self globalKeyMap];
    NSArray* allKeys = [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (rowIndex >= 0 && rowIndex < [allKeys count]) {
        return [allKeys objectAtIndex:rowIndex];
    } else {
        return nil;
    }
}

+ (NSDictionary *)keyMappingsForProfile:(Profile *)profile {
    return profile[KEY_KEYBOARD_MAP];
}

+ (NSDictionary *)touchBarItemsForProfile:(Profile *)profile {
    return profile[KEY_TOUCHBAR_MAP];
}

+ (NSArray<NSString *> *)sortedKeysForKeyMappingsInProfile:(Profile *)profile {
    NSDictionary *km = [profile objectForKey:KEY_KEYBOARD_MAP];
    return [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

+ (NSDictionary*)mappingAtIndex:(int)rowIndex forBookmark:(Profile*)bookmark
{
    NSDictionary* km = [bookmark objectForKey:KEY_KEYBOARD_MAP];
    NSArray* allKeys = [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (rowIndex >= 0 && rowIndex < [allKeys count]) {
        return [km objectForKey:[allKeys objectAtIndex:rowIndex]];
    } else {
        return nil;
    }
}

+ (NSDictionary*)globalMappingAtIndex:(int)rowIndex
{
    NSDictionary* km = [self globalKeyMap];
    NSArray* allKeys = [[km allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    if (rowIndex >= 0 && rowIndex < [allKeys count]) {
        return [km objectForKey:[allKeys objectAtIndex:rowIndex]];
    } else {
        return nil;
    }
}

+ (int)numberOfMappingsForBookmark:(Profile*)bmDict
{
    NSDictionary* keyMapDict = [bmDict objectForKey:KEY_KEYBOARD_MAP];
    return [keyMapDict count];
}

+ (void)removeMappingWithCode:(unichar)keyCode
                    modifiers:(unsigned int)mods
                   inBookmark:(NSMutableDictionary*)bookmark {
    NSMutableDictionary* km = [NSMutableDictionary dictionaryWithDictionary:[bookmark objectForKey:KEY_KEYBOARD_MAP]];
    NSString* keyString = [NSString stringWithFormat:@"0x%x-0x%x", keyCode, mods];
    [km removeObjectForKey:keyString];
    [bookmark setObject:km forKey:KEY_KEYBOARD_MAP];
}

+ (NSInteger)_cgMaskForMod:(int)mod
{
    switch (mod) {
        case kPreferencesModifierTagControl:
            return kCGEventFlagMaskControl;

        case kPreferencesModifierTagLeftOption:
        case kPreferencesModifierTagRightOption:
        case kPreferencesModifierTagEitherOption:
            return kCGEventFlagMaskAlternate;

        case kPreferencesModifierTagEitherCommand:
        case kPreferencesModifierTagLeftCommand:
        case kPreferencesModifierTagRightCommand:
            return kCGEventFlagMaskCommand;

        case kPreferencesModifierTagCommandAndOption:
            return kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;

        default:
            return 0;
    }
}

+ (NSInteger)_nxMaskForLeftMod:(int)mod
{
    switch (mod) {
        case kPreferencesModifierTagControl:
            return NX_DEVICELCTLKEYMASK;

        case kPreferencesModifierTagLeftOption:
            return NX_DEVICELALTKEYMASK;

        case kPreferencesModifierTagRightOption:
            return NX_DEVICERALTKEYMASK;

        case kPreferencesModifierTagEitherOption:
            return NX_DEVICELALTKEYMASK;

        case kPreferencesModifierTagRightCommand:
            return NX_DEVICERCMDKEYMASK;

        case kPreferencesModifierTagLeftCommand:
        case kPreferencesModifierTagEitherCommand:
            return NX_DEVICELCMDKEYMASK;

        case kPreferencesModifierTagCommandAndOption:
            return NX_DEVICELCMDKEYMASK | NX_DEVICELALTKEYMASK;

        default:
            return 0;
    }
}

+ (NSInteger)_nxMaskForRightMod:(int)mod
{
    switch (mod) {
        case kPreferencesModifierTagControl:
            return NX_DEVICERCTLKEYMASK;

        case kPreferencesModifierTagLeftOption:
            return NX_DEVICELALTKEYMASK;

        case kPreferencesModifierTagRightOption:
            return NX_DEVICERALTKEYMASK;

        case kPreferencesModifierTagEitherOption:
            return NX_DEVICERALTKEYMASK;

        case kPreferencesModifierTagLeftCommand:
            return NX_DEVICELCMDKEYMASK;

        case kPreferencesModifierTagRightCommand:
        case kPreferencesModifierTagEitherCommand:
            return NX_DEVICERCMDKEYMASK;

        case kPreferencesModifierTagCommandAndOption:
            return NX_DEVICERCMDKEYMASK | NX_DEVICERALTKEYMASK;

        default:
            return 0;
    }
}

+ (NSInteger)_cgMaskForLeftCommandKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] leftCommandRemapping]];
}

+ (NSInteger)_cgMaskForRightCommandKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] rightCommandRemapping]];
}

+ (NSInteger)_nxMaskForLeftCommandKey
{
    return [self _nxMaskForLeftMod:[[iTermModifierRemapper sharedInstance] leftCommandRemapping]];
}

+ (NSInteger)_nxMaskForRightCommandKey
{
    return [self _nxMaskForRightMod:[[iTermModifierRemapper sharedInstance] rightCommandRemapping]];
}

+ (NSInteger)_cgMaskForLeftAlternateKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] leftOptionRemapping]];
}

+ (NSInteger)_cgMaskForRightAlternateKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] rightOptionRemapping]];
}

+ (NSInteger)_nxMaskForLeftAlternateKey
{
    return [self _nxMaskForLeftMod:[[iTermModifierRemapper sharedInstance] leftOptionRemapping]];
}

+ (NSInteger)_nxMaskForRightAlternateKey
{
    return [self _nxMaskForRightMod:[[iTermModifierRemapper sharedInstance] rightOptionRemapping]];
}

+ (NSInteger)_cgMaskForLeftControlKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] controlRemapping]];
}

+ (NSInteger)_cgMaskForRightControlKey
{
    return [self _cgMaskForMod:[[iTermModifierRemapper sharedInstance] controlRemapping]];
}

+ (NSInteger)_nxMaskForLeftControlKey
{
    return [self _nxMaskForLeftMod:[[iTermModifierRemapper sharedInstance] controlRemapping]];
}

+ (NSInteger)_nxMaskForRightControlKey
{
    return [self _nxMaskForRightMod:[[iTermModifierRemapper sharedInstance] controlRemapping]];
}

+ (CGEventRef)remapModifiersInCGEvent:(CGEventRef)cgEvent {
    // This function copied from cmd-key happy. See copyright notice at top.
    CGEventFlags flags = CGEventGetFlags(cgEvent);
    DLog(@"Performing remapping. On input CGEventFlags=%@", @(flags));
    CGEventFlags andMask = -1;
    CGEventFlags orMask = 0;

    // flags contains both device-dependent flags and device-independent flags.
    // The device-independent flags are named kCGEventFlagMaskXXX or NX_xxxMASK
    // The device-dependent flags are named NX_DEVICExxxKEYMASK
    // Device-independent flags do not indicate leftness or rightness.
    // Device-dependent flags do.
    // Generally, you get both sets of flags. But this does not have to be the case if an event
    // is synthesized, as seen in issue 5207 where Flycut does not set the device-dependent flags.
    // If the event lacks device-specific flags we'll add them when synergyModifierRemappingEnabled
    // is on. Otherwise, we don't remap them.
    if (flags & kCGEventFlagMaskCommand) {
        BOOL hasDeviceIndependentFlagsForCommandKey = ((flags & (NX_DEVICELCMDKEYMASK | NX_DEVICERCMDKEYMASK)) != 0);
        if (!hasDeviceIndependentFlagsForCommandKey) {
            if ([iTermAdvancedSettingsModel synergyModifierRemappingEnabled]) {
                flags |= NX_DEVICELCMDKEYMASK;
                hasDeviceIndependentFlagsForCommandKey = YES;
            }
        }
        if (hasDeviceIndependentFlagsForCommandKey) {
            andMask &= ~kCGEventFlagMaskCommand;
            if (flags & NX_DEVICELCMDKEYMASK) {
                andMask &= ~NX_DEVICELCMDKEYMASK;
                orMask |= [self _cgMaskForLeftCommandKey];
                orMask |= [self _nxMaskForLeftCommandKey];
            }
            if (flags & NX_DEVICERCMDKEYMASK) {
                andMask &= ~NX_DEVICERCMDKEYMASK;
                orMask |= [self _cgMaskForRightCommandKey];
                orMask |= [self _nxMaskForRightCommandKey];
            }
        }
    }
    if (flags & kCGEventFlagMaskAlternate) {
        BOOL hasDeviceIndependentFlagsForOptionKey = ((flags & (NX_DEVICELALTKEYMASK | NX_DEVICERALTKEYMASK)) != 0);
        if (!hasDeviceIndependentFlagsForOptionKey) {
            if ([iTermAdvancedSettingsModel synergyModifierRemappingEnabled]) {
                flags |= NX_DEVICELALTKEYMASK;
                hasDeviceIndependentFlagsForOptionKey = YES;
            }
        }
        if (hasDeviceIndependentFlagsForOptionKey) {
            andMask &= ~kCGEventFlagMaskAlternate;
            if (flags & NX_DEVICELALTKEYMASK) {
                andMask &= ~NX_DEVICELALTKEYMASK;
                orMask |= [self _cgMaskForLeftAlternateKey];
                orMask |= [self _nxMaskForLeftAlternateKey];
            }
            if (flags & NX_DEVICERALTKEYMASK) {
                andMask &= ~NX_DEVICERALTKEYMASK;
                orMask |= [self _cgMaskForRightAlternateKey];
                orMask |= [self _nxMaskForRightAlternateKey];
            }
        }
    }
    if (flags & kCGEventFlagMaskControl) {
        BOOL hasDeviceIndependentFlagsForControlKey = ((flags & (NX_DEVICELCTLKEYMASK | NX_DEVICERCTLKEYMASK)) != 0);
        if (!hasDeviceIndependentFlagsForControlKey) {
            if ([iTermAdvancedSettingsModel synergyModifierRemappingEnabled]) {
                flags |= NX_DEVICELCTLKEYMASK;
                hasDeviceIndependentFlagsForControlKey = YES;
            }
        }
        if (hasDeviceIndependentFlagsForControlKey) {
            andMask &= ~kCGEventFlagMaskControl;
            if (flags & NX_DEVICELCTLKEYMASK) {
                andMask &= ~NX_DEVICELCTLKEYMASK;
                orMask |= [self _cgMaskForLeftControlKey];
                orMask |= [self _nxMaskForLeftControlKey];
            }
            if (flags & NX_DEVICERCTLKEYMASK) {
                andMask &= ~NX_DEVICERCTLKEYMASK;
                orMask |= [self _cgMaskForRightControlKey];
                orMask |= [self _nxMaskForRightControlKey];
            }
        }
    }
    DLog(@"On output CGEventFlags=%@", @((flags & andMask) | orMask));

    CGEventSetFlags(cgEvent, (flags & andMask) | orMask);
    return cgEvent;
}

+ (NSEvent*)remapModifiers:(NSEvent*)event
{
    return [NSEvent eventWithCGEvent:[iTermKeyBindingMgr remapModifiersInCGEvent:[event CGEvent]]];
}

+ (NSString *)keyForMappingReferencingProfileWithGuid:(NSString *)guid inProfile:(Profile *)profile {
    __block NSString *theKey = nil;
    NSDictionary *keyboardMap = profile[KEY_KEYBOARD_MAP];

    // Search for a keymapping with an action that references a profile.
    [keyboardMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull keyMap, BOOL * _Nonnull stop) {
        int action = [keyMap[iTermKeyBindingDictionaryKeyAction] intValue];
        if (action == KEY_ACTION_NEW_TAB_WITH_PROFILE ||
            action == KEY_ACTION_NEW_WINDOW_WITH_PROFILE ||
            action == KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE ||
            action == KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE ||
            action == KEY_ACTION_SET_PROFILE) {
            NSString *referencedGuid = keyMap[iTermKeyBindingDictionaryKeyParameter];
            if ([referencedGuid isEqualToString:guid]) {
                theKey = [[key copy] autorelease];
                *stop = YES;
            }
        }
    }];
    return theKey;
}

+ (Profile *)removeMappingsReferencingGuid:(NSString*)guid fromBookmark:(Profile *)bookmark {
    if (bookmark) {
        NSMutableDictionary *mutableBookmark = nil;
        NSString *keyToRemove = [self keyForMappingReferencingProfileWithGuid:guid inProfile:bookmark];
        while (keyToRemove) {
            NSInteger i = [[self sortedKeysForKeyMappingsInProfile:mutableBookmark ?: bookmark] indexOfObject:keyToRemove];
            if (i != NSNotFound) {
                if (!mutableBookmark) {
                    mutableBookmark = [[bookmark mutableCopy] autorelease];
                }
                [iTermKeyBindingMgr removeMappingAtIndex:i inBookmark:mutableBookmark];
            } else {
                XLog(@"Profile with guid %@ has key mapping referencing guid %@ with key %@ but I can't find it in sorted keys",
                     bookmark[KEY_GUID],
                     guid,
                     keyToRemove);
                break;
            }
            keyToRemove = [self keyForMappingReferencingProfileWithGuid:guid inProfile:mutableBookmark ?: bookmark];
        };
        return mutableBookmark;
    } else {
        BOOL change;
        do {
            NSMutableDictionary* mutableGlobalKeyMap = [NSMutableDictionary dictionaryWithDictionary:[iTermKeyBindingMgr globalKeyMap]];
            change = NO;
            for (int i = 0; i < [mutableGlobalKeyMap count]; i++) {
                NSDictionary* keyMap = [iTermKeyBindingMgr globalMappingAtIndex:i];
                int action = [[keyMap objectForKey:iTermKeyBindingDictionaryKeyAction] intValue];
                if (action == KEY_ACTION_NEW_TAB_WITH_PROFILE ||
                    action == KEY_ACTION_NEW_WINDOW_WITH_PROFILE ||
                    action == KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE ||
                    action == KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE ||
                    action == KEY_ACTION_SET_PROFILE) {
                    NSString* referencedGuid = [keyMap objectForKey:iTermKeyBindingDictionaryKeyParameter];
                    if ([referencedGuid isEqualToString:guid]) {
                        mutableGlobalKeyMap = [iTermKeyBindingMgr removeMappingAtIndex:i
                                                                          inDictionary:mutableGlobalKeyMap];
                        [iTermKeyBindingMgr setGlobalKeyMap:mutableGlobalKeyMap];
                        change = YES;
                        break;
                    }
                }
            }
        } while (change);
        return nil;
    }
}


@end
