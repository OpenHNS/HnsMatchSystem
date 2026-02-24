enum _: GAMEPLAYS {
	GAMEPLAY_HNS,
	GAMEPLAY_KNIFE,
	GAMEPLAY_TRAINING,
	GAMEPLAY_BATTLERACE
}

new g_iCurrentGameplay;

enum _: GP_FUNCS {
	GP_ENABLE,
	GP_DISABLE,
	GP_SETROLE,
	GP_KILLED,
	GP_ROUNDSTART,
	GP_ROUNDEND
};

new g_GPFuncs[GAMEPLAYS][GP_FUNCS];

public init_gameplay() {
	hns_init();
	knife_init();
	training_init();
	battle_init();
}


public ChangeGameplay(iMode) {
	switch (g_iCurrentGameplay) {
		case GAMEPLAY_HNS:
			hns_disable_rules();
		case GAMEPLAY_TRAINING:
			training_disable_rules();
		case GAMEPLAY_BATTLERACE:
			battle_disable_rules();
	}

	switch (iMode) {
		case GAMEPLAY_HNS: {
			hns_enable_rules();
		}
		case GAMEPLAY_TRAINING: {
			training_enable_rules();
		}
		case GAMEPLAY_KNIFE: {
			knife_enable_rules();
		}
		case GAMEPLAY_BATTLERACE: {
			battle_enable_rules();
		}
	}

	g_iCurrentGameplay = iMode;
}
