/*
    TitleAndSymbolView
    Mimic Control Center's menu item views

    (c) 2024 Ricci Adams
    MIT License / 1-clause BSD License
*/

@import AppKit;

@interface TitleAndSymbolView : NSControl

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbol;

@property (nonatomic, getter=isSelected) BOOL selected;

@property (weak) id representedObject;

@end
