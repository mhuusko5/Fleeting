#import "FleetingController.h"
OBJC_EXTERN UIImage *_UICreateScreenUIImage(void) NS_RETURNS_RETAINED;

@interface FleetingController ()

@property BOOL activated;
@property UIWindow *mainWindow;
@property UIView *mainView;
@property UIButton *closeButton;
@property UISwitch *autoSwitch;
@property UILabel *pauseResumeLabel;
@property UISlider *wpmSlider;
@property UILabel *wpmValueLabel;
@property UIView *spritzContainer;
@property AFSpritzLabel *spritzLabel;
@property AFSpritzManager *spritzManager;
@property NSString *currentText;

@end

@implementation FleetingController

- (id)init {
	self = [super init];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deactivate:) name:UIApplicationWillResignActiveNotification object:nil];

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), deviceSleep, CFSTR("com.apple.springboard.hasBlankedScreen"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	return self;
}

- (void)deactivate:(id)sender {
	if (_spritzManager) {
		[_spritzManager pauseReading];
		_spritzManager = nil;
	}

	_mainWindow.hidden = YES;
	_mainWindow = nil;

	_activated = NO;
}

static void deviceSleep(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	[(__bridge FleetingController *)observer deactivate : nil];
}

- (void)activateWithText:(NSString *)text {
	_activated = YES;

	_currentText = text;

	[self loadInterface];

	[UIView animateWithDuration:0.3 animations: ^(void) {
	    _mainWindow.alpha = 1;
	}];

	[self setupControls];
}

- (void)autoSwitchChanged:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:_autoSwitch.on forKey:@"autoStart"];
	[[NSUserDefaults standardUserDefaults] synchronize];

    if (_spritzManager && [_spritzManager status:AFSpritzStatusNotStarted]) {
		[self start];
	}
}

static NSTimer *changeWpmTimer = nil;
- (void)wpmSliderChanged:(id)sender {
	int newWpm = (int)_wpmSlider.value;
	_wpmValueLabel.text = [NSString stringWithFormat:@"%i", newWpm];
	[[NSUserDefaults standardUserDefaults] setInteger:newWpm forKey:@"wordsPerMinute"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	if (changeWpmTimer) {
		[changeWpmTimer invalidate];
		changeWpmTimer = nil;
	}

	changeWpmTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 block: ^{
	    if (_spritzManager) {
	        [_spritzManager pauseReading];
	        _spritzManager = nil;
	        _spritzManager = [[AFSpritzManager alloc] initWithText:_currentText andWordsPerMinute:newWpm];
	        [self start];
		}
	} repeats:NO];
}

- (void)adjustPauseResumeButton {
	[_pauseResumeLabel sizeToFit];
	float pauseResumeLabelOffset = _mainView.frame.size.width / 24;
	CGRect pauseResumeLabelFrame = _pauseResumeLabel.frame;
	pauseResumeLabelFrame.origin.x = _mainView.frame.size.width - pauseResumeLabelFrame.size.width - pauseResumeLabelOffset;
	pauseResumeLabelFrame.origin.y = _mainView.frame.size.height - (0.85 * pauseResumeLabelFrame.size.height) - pauseResumeLabelOffset;
	_pauseResumeLabel.frame = pauseResumeLabelFrame;
}

- (void)pauseResume {
	if (_spritzManager) {
		if ([_spritzManager status:AFSpritzStatusStopped]) {
			[_spritzManager resumeReading];
			_pauseResumeLabel.text = @"Pause";
			[self adjustPauseResumeButton];
		}
		else if ([_spritzManager status:AFSpritzStatusReading]) {
			[_spritzManager pauseReading];
			_pauseResumeLabel.text = @"Resume";
			[self adjustPauseResumeButton];
		}
		else if ([_spritzManager status:AFSpritzStatusNotStarted]) {
			[self start];
		}
	}
}

- (void)start {
	[_spritzManager updateLabelWithNewWordAndCompletion: ^(AFSpritzWords *word, BOOL finished) {
	    if (!finished) {
	        _spritzLabel.word = word;
		}
	    else {
	        [self deactivate:nil];
		}
	}];
	_pauseResumeLabel.text = @"Pause";
	[self adjustPauseResumeButton];
}

- (void)setupControls {
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"wordsPerMinute"]) {
		_wpmSlider.value = (float)[[NSUserDefaults standardUserDefaults] integerForKey:@"wordsPerMinute"];
		_wpmValueLabel.text = [NSString stringWithFormat:@"%i", (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"wordsPerMinute"]];
	}
	else {
		_wpmSlider.value = 300.0;
		_wpmValueLabel.text = @"300";
		[[NSUserDefaults standardUserDefaults] setInteger:300 forKey:@"wordsPerMinute"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	_spritzManager = [[AFSpritzManager alloc] initWithText:_currentText andWordsPerMinute:_wpmSlider.value];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autoStart"]) {
		_autoSwitch.on = YES;
		[self performSelector:@selector(start) withObject:nil afterDelay:0.4];
	}
	else {
		_autoSwitch.on = NO;
	}

	[_closeButton addTarget:self action:@selector(deactivate:) forControlEvents:UIControlEventTouchDown];

	[_autoSwitch addTarget:self action:@selector(autoSwitchChanged:) forControlEvents:UIControlEventValueChanged];

	UITapGestureRecognizer *pauseResumeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pauseResume)];
	pauseResumeTap.numberOfTapsRequired = 1;
	[_pauseResumeLabel addGestureRecognizer:pauseResumeTap];
	_pauseResumeLabel.userInteractionEnabled = YES;

	UITapGestureRecognizer *spritzContainerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pauseResume)];
	spritzContainerTap.numberOfTapsRequired = 1;
	[_spritzContainer addGestureRecognizer:spritzContainerTap];
	_spritzContainer.userInteractionEnabled = YES;

	[_wpmSlider addTarget:self action:@selector(wpmSliderChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)loadInterface {
	_mainWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	_mainWindow.rootViewController = self;
	_mainWindow.windowLevel = UIWindowLevelAlert;
	_mainWindow.exclusiveTouch = YES;
	_mainWindow.alpha = 0;
	[_mainWindow makeKeyAndVisible];

	UIImageView *backgroundImage = [[UIImageView alloc] initWithImage:_UICreateScreenUIImage()];
	backgroundImage.frame = _mainWindow.frame;
	[_mainWindow addSubview:backgroundImage];

	FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:_mainWindow.frame];
	blurView.backgroundColor = [UIColor clearColor];
	blurView.tintColor = [UIColor clearColor];
	blurView.dynamic = NO;
	blurView.blurRadius = 40.0f;
	blurView.underlyingView = backgroundImage;
	[_mainWindow addSubview:blurView];

	_mainView = [[UIView alloc] initWithFrame:_mainWindow.frame];
	_mainView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];

	_closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_closeButton.frame = CGRectMake(_mainView.frame.size.width / 80, _mainView.frame.size.width / 80 + _mainView.frame.size.width / 100, _mainView.frame.size.width / 10, _mainView.frame.size.width / 10);
	_closeButton.font = [UIFont fontWithName:@"GillSans-Light" size:_mainView.frame.size.width / 11];
	[_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_closeButton setTitle:@"X" forState:UIControlStateNormal];
	[_mainView addSubview:_closeButton];

	_spritzContainer = [[UIView alloc] initWithFrame:CGRectMake(0, _mainView.frame.size.height / 4, _mainView.frame.size.width, _mainView.frame.size.height / 10)];
	_spritzContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.94];
	_spritzLabel = [[AFSpritzLabel alloc] initWithFrame:CGRectMake(0, 0, _spritzContainer.frame.size.width, _spritzContainer.frame.size.height)];
	_spritzLabel.textFont = [UIFont fontWithName:@"Menlo" size:_spritzContainer.frame.size.height / 1.9];
	_spritzLabel.backgroundColor = [UIColor clearColor];
	[_spritzContainer addSubview:_spritzLabel];
	[_mainView addSubview:_spritzContainer];

	UILabel *autoLabel = [[UILabel alloc] init];
	autoLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_mainView.frame.size.width / 12];
	autoLabel.textColor = [UIColor whiteColor];
	[autoLabel setText:@"Auto-start:"];
	[autoLabel sizeToFit];
	float autoLabelOffset = _mainView.frame.size.width / 24;
	CGRect autoLabelFrame = autoLabel.frame;
	autoLabelFrame.origin.x = autoLabelOffset;
	autoLabelFrame.origin.y = _mainView.frame.size.height - (0.85 * autoLabelFrame.size.height) - autoLabelOffset;
	autoLabel.frame = autoLabelFrame;
	[_mainView addSubview:autoLabel];

	_autoSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
	CGRect autoSwitchFrame = _autoSwitch.frame;
	autoSwitchFrame.origin.x = autoLabel.frame.origin.x + (autoLabel.frame.size.width * 1.08);
	autoSwitchFrame.origin.y = _mainView.frame.size.height - autoSwitchFrame.size.height - (autoLabelOffset / 1.85);
	_autoSwitch.frame = autoSwitchFrame;
	[_mainView addSubview:_autoSwitch];

	_pauseResumeLabel = [[UILabel alloc] init];
	_pauseResumeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_mainView.frame.size.width / 12];
	_pauseResumeLabel.textColor = [UIColor whiteColor];
	[_pauseResumeLabel setText:@"Resume"];
	[self adjustPauseResumeButton];
	[_mainView addSubview:_pauseResumeLabel];

	UILabel *wpmLabel = [[UILabel alloc] init];
	wpmLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_mainView.frame.size.width / 12];
	wpmLabel.textColor = [UIColor whiteColor];
	[wpmLabel setText:@"WPM: "];
	[wpmLabel sizeToFit];
	CGRect wpmLabelFrame = wpmLabel.frame;
	wpmLabelFrame.origin.x = autoLabelOffset;
	wpmLabelFrame.origin.y = _mainView.frame.size.height - (0.85 * wpmLabelFrame.size.height) - _autoSwitch.frame.size.height - (1.5 * autoLabelOffset);
	wpmLabel.frame = wpmLabelFrame;
	[_mainView addSubview:wpmLabel];

	_wpmValueLabel = [[UILabel alloc] init];
	_wpmValueLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_mainView.frame.size.width / 12];
	_wpmValueLabel.textColor = [UIColor whiteColor];
	[_wpmValueLabel setText:@"350"];
	[_wpmValueLabel sizeToFit];
	CGRect wpmValueLabelFrame = _wpmValueLabel.frame;
	wpmValueLabelFrame.origin.x = _mainView.frame.size.width - wpmValueLabelFrame.size.width - autoLabelOffset;
	wpmValueLabelFrame.origin.y = _mainView.frame.size.height - (0.85 * wpmValueLabelFrame.size.height) - _autoSwitch.frame.size.height - (1.5 * autoLabelOffset);
	_wpmValueLabel.frame = wpmValueLabelFrame;
	[_mainView addSubview:_wpmValueLabel];

	_wpmSlider = [[UISlider alloc] initWithFrame:_mainView.frame];
	[_wpmSlider sizeToFit];
	CGRect wpmSliderFrame = _wpmSlider.frame;
	wpmSliderFrame.origin.x = wpmLabel.frame.origin.x + wpmLabel.frame.size.width + (autoLabelOffset / 4);
	wpmSliderFrame.size.width = _mainView.frame.size.width - wpmSliderFrame.origin.x - (_wpmValueLabel.frame.size.width + (autoLabelOffset * 2));
	wpmSliderFrame.origin.y = _mainView.frame.size.height - wpmSliderFrame.size.height - _autoSwitch.frame.size.height - (1.0 * autoLabelOffset);
	_wpmSlider.frame = wpmSliderFrame;
	_wpmSlider.minimumValue = 200.0;
	_wpmSlider.maximumValue = 900.0;
	[_mainView addSubview:_wpmSlider];

	[_mainWindow addSubview:_mainView];
}

+ (id)sharedInstance {
	static dispatch_once_t once;
	static id instance;
	dispatch_once(&once, ^{
	    instance = self.new;
	});
	return instance;
}

@end
