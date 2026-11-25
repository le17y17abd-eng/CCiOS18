#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// CCiOS18 visual layer for iOS 15 Control Center.
// Native Control Center modules and their actions are intentionally preserved.
static const NSInteger kCCiOS18BackdropTag = 180018;
static const void *kCCiOS18StyledKey = &kCCiOS18StyledKey;

static void CCiOS18InstallBackdrop(UIView *root) {
    if (!root || [root viewWithTag:kCCiOS18BackdropTag]) return;

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:effect];
    backdrop.tag = kCCiOS18BackdropTag;
    backdrop.userInteractionEnabled = NO;
    backdrop.alpha = 0.96;
    backdrop.frame = root.bounds;
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *tint = [[UIView alloc] initWithFrame:backdrop.bounds];
    tint.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.18];
    tint.userInteractionEnabled = NO;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [backdrop.contentView addSubview:tint];

    [root insertSubview:backdrop atIndex:0];
}

static BOOL CCiOS18IsModuleView(UIView *view) {
    if (!view) return NO;
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"Controller"]) return NO;
    return [name containsString:@"Module"] || [name containsString:@"module"];
}

static void CCiOS18StyleModuleTree(UIView *view) {
    if (!view) return;

    if (CCiOS18IsModuleView(view) &&
        ![objc_getAssociatedObject(view, kCCiOS18StyledKey) boolValue]) {
        objc_setAssociatedObject(view, kCCiOS18StyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        view.layer.cornerRadius = 19.0;
        if (@available(iOS 13.0, *)) {
            view.layer.cornerCurve = kCACornerCurveContinuous;
        }
        view.layer.borderWidth = 0.75;
        view.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;

        // A restrained translucent fill gives native modules a glass-card finish.
        view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.16];
    }

    for (UIView *child in view.subviews) {
        CCiOS18StyleModuleTree(child);
    }
}

%hook CCUIModularControlCenterOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;

    UIView *root = [(UIViewController *)self view];
    CCiOS18InstallBackdrop(root);
    CCiOS18StyleModuleTree(root);
}

%end
