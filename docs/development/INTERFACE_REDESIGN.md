# Simplified setup and stable preview (2026-10-22)

Requested in Telegram48839: simplify the operation UI and stop the center preview
from growing/shrinking when choosing a phase or mechanic.

## Interaction

- Two columns: fixed-width selection card (phase, mechanic, method, role), plus a
  large preview. A single persistent bottom primary action starts the course;
  the secondary action is explicitly an unscored demonstration.
- Advanced settings use an explicit modal with Practice settings, Party/review
  and Controls tabs. Seeds, assignments, speed, checkpoints, custom profiles and
  conditional P6 job/LB selectors are retained, not removed.
- Only active practice offers Resume. Settings pause/resume ownership and the
  same live world/actors survive the fullscreen transition. Practice remains
  game-only by default with the eight-member status HUD.
- Full mechanic names and long method descriptions remain available as tooltips.
  Camera drag/zoom/overview/reset remain next to the preview. Changing a mechanic
  no longer resets the user's camera orientation/distance.

## Root causes fixed

1. Old left/right HBox columns propagated minimum widths from OptionButton labels
   and long text. Center heading/cue/note wrapping consumed variable height.
2. Every setup call reset SubViewportContainer anchors/offsets to TOP_LEFT, even
   when already in setup. This forcibly restored its 350x300 minimum rectangle,
   and a container sort was not guaranteed when its minimum size had not changed.

The two columns now use independent anchored bounds under a plain Control;
headings/cues have bounded single-line height, descriptive text has fixed bounds,
OptionButtons do not fit their longest item, and P6 details live in the modal.
Only an actual return from fullscreen resets viewport anchors. The owning VBox
explicitly queues a sort, instead of repeatedly forcing its child's rectangle.

At logical1440x900, the preview is1048x604 at(372,161), unchanged through phase,
mechanic, method, conditional P6 details and fullscreen-return transitions.
The project keeps its existing canvas_items scaling; changing the physical window
size scales the logical UI, not its selection-dependent geometry.

## Verification

- Setup layout:498 assertions,175 method selections (100 unique offered methods
  at1440x900 plus75 repeated cases at three additional physical sizes),0 failures.
  Includes all20 mechanics, extreme-length text, source-routed actual button
  clicks, explicit strategy requirement and fullscreen/settings/resume lifecycle.
- Real Linux X11/Mesa rendered source smoke:25 assertions /2 representative
  methods /0 failures; reviewed ready and advanced-modal captures.
- Presentation27/0; input routing20/0; marker-library36/0; actual marker UI9/0.
  Text-input fixtures now open the actual visible settings modal before focusing
  the seed, rather than assuming a hidden editor can receive focus.
- Exact Linux exported executable launched with a rendered native window, selected
  Program Loop via its supported CLI, and saved the README screenshot. No AnAn or
  installed game was required. Screenshot is a real export, not a UI mockup.
- Windows: AnAn connectivity timed out; no new native Windows acceptance claimed.
- Web: export succeeded. Two live-browser approaches reached driver-connection
  failure (one after engine/WebGL2 startup, during screenshot). Browser blank-page
  control succeeded. Root cause is unproven; no Web passing claim or new Web release.
  Preserve diagnostics in the work-guard logs and /tmp/top-web-ui-v034 locally.

No mechanic/server calibration or full AVFX-fidelity claim is added by this UI work.
