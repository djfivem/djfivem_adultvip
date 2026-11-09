-- Fixture shaped like rpemotes-reborn AnimationList.lua / AnimationListCustom.lua.
-- It is not loaded by FiveM. The parser test executes nothing in this file.

RP = RP or {}

RP.AnimalEmotes = {
    ["bdogfhump"] = {
        "creatures@rottweiler@amb@",
        "hump_loop_ladydog",
        "Female Hump (big dog)",
        AnimationOptions = {
            onFootFlag = AnimFlag.LOOP
        },
        AdultAnimation = true,
        AnimalEmote = true
    },
}

RP.Shared = {
    ["kiss"] = {
        "hs3_ext-20",
        "cs_lestercrest_3_dual-20",
        "Kiss",
        "kiss2",
        AnimationOptions = {
            EmoteDuration = 10000,
            SyncOffsetFront = 0.08
        }
    },
    ["kiss2"] = {
        "hs3_ext-20",
        "csb_georginacheng_dual-20",
        "Kiss 2",
        "kiss",
        AnimationOptions = {
            EmoteDuration = 10000,
            SyncOffsetFront = 0.08
        }
    },
    ["hugpose"] = {
        "amnilka@photopose@couple@couplefirst",
        "amnilka_couple_mal_001",
        "Hug Pose",
        "hugpose2",
        AnimationOptions = {
            onFootFlag = AnimFlag.LOOP
        }
    },
    ["hugpose2"] = {
        "amnilka@photopose@couple@couplefirst",
        "amnilka_couple_fem_001",
        "Hug Pose With Me?",
        "hugpose",
        AnimationOptions = {
            onFootFlag = AnimFlag.LOOP,
            Attachto = true,
            bone = 0,
            pos = vector3(0.1400, 0.2500, 0.0000),
            rot = vector3(0.0000, 0.0000, 0.0000),
        }
    },
    ["csdog"] = {
        "anim@heists@box_carry@",
        "idle",
        "Carry Small Dog",
        "csdog2",
        AnimationOptions = {
            onFootFlag = AnimFlag.MOVING,
        },
        AnimalEmote = true
    },
}

RP.Dances = {
    ["lapdance"] = {
        "mp_safehouse",
        "lap_dance_girl",
        "Lapdance"
    },
    ["twerk"] = {
        "switch@trevor@mocks_lapdance",
        "001443_01_trvs_28_idle_stripper",
        "Twerk",
        AnimationOptions = {
            onFootFlag = AnimFlag.LOOP
        }
    },
}

RP.Emotes = {
    ["fspose"] = {
        "missfam5_yoga",
        "c2_pose",
        "F Sex Pose",
        AnimationOptions = {
            onFootFlag = AnimFlag.LOOP
        },
        AdultAnimation = true
    },
    ["pee"] = {
        "misscarsteal2peeing",
        "peeing_loop",
        "Pee (Male)",
        AnimationOptions = {
            onFootFlag = AnimFlag.STUCK,
            PtfxAsset = "scr_amb_chop",
            PtfxName = "ent_anim_dog_peeing",
            PtfxPlacement = {
                -0.05,
                0.3,
                0.0,
                0.0,
                90.0,
                90.0,
                1.0
            },
            PtfxInfo = Translate('pee'),
            PtfxCanHold = true,
        },
        AdultAnimation = true
    },
    ["atm"] = {
        "Scenario",
        "PROP_HUMAN_ATM",
        "ATM"
    },
    ["smoke"] = { -- a quote in a comment should not matter: "RP.Emotes = {"
        "amb@world_human_aa_smoke@male@idle_a",
        "idle_c",
        "Smoke",
    },
}

RP.PropEmotes = {
    ["jerkf"] = {
        "switch@trevor@jerking_off",
        "trev_jerking_off_loop",
        "JerkOff! Female",
        AnimationOptions = {
            Prop = 'prop_cs_dildo_01',
            PropBone = 28422,
            PropPlacement = {
                0.09,
                0.05,
                -0.03,
                90.0,
                80.0,
                30.0
            },
            onFootFlag = AnimFlag.MOVING,
        },
        AdultAnimation = true
    },
}

local CustomDP = {}
CustomDP.Shared = {}
CustomDP.Emotes = {}

CustomDP.Emotes["custompose"] = {
    "export@custom_pose",
    "custom_clip",
    "Custom Pose",
    AnimationOptions = {
        EmoteLoop = true
    },
    AdultAnimation = true
}
