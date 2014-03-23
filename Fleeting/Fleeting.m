#import "ActionMenu/ActionMenu.h"
#import "FleetingController.h"

@implementation UIResponder (FleetingAction)

- (NSString *)trimmedSelection {
	NSString *selection = self.selectedTextualRepresentation;

	if (!selection || selection.length < 1) {
		return nil;
	}
	else {
		selection = [selection stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		selection = [selection stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, selection.length)];

		if (selection.length < 1) {
			return nil;
		}
		else {
			return selection;
		}
	}
}

- (void)doFleeting:(id)sender {
	NSString *selection = [self trimmedSelection];
	if (selection) {
		[[FleetingController sharedInstance] activateWithText:selection];
	}
}

- (BOOL)canFleeting:(id)sender {
	return ([self trimmedSelection]);
}

+ (void)load {
	[[UIMenuController sharedMenuController] registerAction:@selector(doFleeting:) title:@"Fleeting" canPerform:@selector(canFleeting:)];

	[FleetingController sharedInstance];
}

@end
