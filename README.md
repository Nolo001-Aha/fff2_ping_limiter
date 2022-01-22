# Freak Fortress 2: Ping Limiter

**warning: this is proof-of-concept code. It works, but might have some issues/logic mistakes here and there. Some code is straight up boilerplate and is in severe need of a rewrite. I wrote it back in 2020 and ever since it's only hosting server removed it, it's abandoned. 
Please use at your own risk. Forks or PRs are welcome.**

After basically running a Freak Fortress 2 community for quite some time, I decided to introduce a customizable ping limiting plugin. Available plugins mostly suggested exactly the same solution - kick a high-pinged player.
In my opinion, simply kicking a player isn't a very good thing. My idea was to prevent them from becoming bosses, but let them play as the opposite team. Basically, that's how this plugin came to life.

**What it does**

In general words, this plugin manages the ability to become a boss based on ping. Whenever someone's ping reaches or goes beyond a certain value, they lose their ability to become a boss. They are blocked from becoming bosses for as long as their ping is beyond the limit. This is achieved by removing player Queue Points and temporarily storing them in memory. Once their ping stabilizes, they are allowed to play as bosses again.

**What are the options**

This plugin has two main modes - Static and Dynamic.

1. **Static**. Pretty straigtforward - you specify a static ping limit, and every player beyond that limit loses their queue points for as long as they are above the max value.
2. **Dynamic**. This one is quirkier, but in general is much less of a hassle to players. What it does is it computes a server-average ping value and uses it as the limit. This prevents cases where the server gets under heavy load or it's connection gets unstable and all players lose their points due to everyone's ping getting too high.

**Runtime dependencies:**

1. Any sensible Freak Fortress 2 version, official or not.


**Installation:**

1. Compile and upload to addons/sourcemod/plugins.
2. Adjust it's ConVars according to your needs. ConVars below.


**ConVars:**

1. **ff2_pinglimit** - set to 0 to disable the plugin completely. Anything above 0 will be treated as a Static maxmimum ping value. Not used if the Mode is set to Dynamic.
2. **ff2_pinglimit_compute** - Average ping calculations for Dynamic Mode are made every -value- seconds. Unused with the Static mode on.
3. **ff2_pingcheckdelay** - the plugins checks players' ping values every -value- seconds.
4. **ff2_pinglimit_chat** - enable chat messages whenever a player loses their points.
5. **ff2_pinglimit_mode** - 0 corresponds to Static mode, 1 is the Dynamic Mode.
6. **ff2_pinglimit_modifier** - additional Average ping value multiplier, used for precise limit adjustments with the Dynamic mode on. Example: set to 0.1 to increase the actual limit by 10% compared to the actual average value.


**Commands**

*sm_maxping* - See current ping limit value in chat.

**How it works in-game:**

Whenever the plugin detects a ping limit violation, the player sees a menu that shows a short description of the plugin's actions. Basically notifies them that their points were temprorarily blocked until their ping stabilizes. They are given two buttons - a simple Close and a "Close and don't show again until ping stabilizes" one.
When their ping stabilizes and gets lower than the limit, they see a corresponding chat message.


**Translations**

Currently has English and Russian translations.

