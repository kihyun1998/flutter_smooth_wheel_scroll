# Adoption in kihyun1998 packages

Which of the publisher's own Flutter packages build a wheel-scrollable view
internally, and whether that view uses `SmoothScrollController`. An app cannot
swap a controller a widget package creates for itself, so each package adopts
it on its own.

Surveyed 2026-10-16 against each repository's `origin/main`, at the commit
listed. Code is named by `file — symbol`.

## Adopted

| Package | Commit | Where |
|---|---|---|
| flutter_table_plus | `af801af` | `lib/src/widgets/synced_scroll_controllers.dart` — `SyncedScrollControllers`; a passed controller wins, `SmoothScrollController(motion:)` otherwise |
| flutter_dropdown_button | `bf9d21c` | `lib/src/shell/dropdown_menu_shell.dart` — `_scrollController` |

## Not adopted

| Priority | Package | Commit | Where | Notes |
|:-:|---|---|---|---|
| 1 | flutter_folderview | `02bd771` | `lib/widgets/synced_scroll_controllers.dart` — `_sc11`, `_sc12`, `_sc21`, `_sc22` | Vertical `ListView.builder` plus horizontal scroll. Same `SyncedScrollControllers` shape as flutter_table_plus, so its change carries over. |
| 2 | flutter_syntax_highlight | `3d219be` | `lib/src/widget/syntax_text.dart` — `_vertical`, `_horizontal` | Code view; the most wheel-heavy widget here. |
| 3 | flutter_show_menu | `554445c` | `lib/src/overlay_menu.dart` — `_scrollController` | Created only when `maxHeight` is set. Same kind of menu as flutter_dropdown_button. |
| 4 | flutter_example_template | `0efe56b` | `lib/src/shell/code_pane.dart` — `_controller` | The code pane swaps its controller. `feature_list_pane.dart`, `shell_menu.dart`, `feature_detail_pane.dart` and `shell_page.dart` build scroll views with no controller, so one has to be added. |
| 5 | just_sonner | `5ba3a10` | `lib/src/host.dart` — `_scroll`, `_scrollFromControl` | Swapping `_scroll` is half of it: `_scrollFromControl` takes the wheel over the control itself and calls `jumpTo`, which still jumps. |
| Low | flutter_split_workspace | `1cef2b0` | `lib/src/features/tabbar/widgets/tab_bar_widget.dart` — `_scrollController` | Horizontal tab row, moved by the wheel only with Shift. Not in the profile's package list. |
| Low | flutter_animation_stepper | `805dd51` | `lib/src/widgets/animation_stepper.dart` — the horizontal `SingleChildScrollView` | Horizontal, no controller. |

Horizontal-only views are ranked low on the reading that Flutter scrolls a
horizontal `Scrollable` by a vertical wheel only with Shift held. That reading
is not yet confirmed against Flutter's source.

## No wheel-scrollable view

flutter_bin, x509_cert_store, flutter_inactive_timer, flutter_ime,
flutter_password_input, flutter_license_manager, flutter_oss_manager,
flutter_checkbox, flutter_otp_widget, flutter_root_context_menu,
flutter_tweakcn_generator, just_color_picker, just_font_scan, just_tooltip,
boring_avatars, ffi_url_launcher.

## Not surveyed

No local clone: flutter_alone, macos_window_toolkit, just_save_gallery,
window_lockable.
