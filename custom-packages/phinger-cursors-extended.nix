# This is a Nix expression for generating a cursor theme that is a superset of `phinger-cursors`,
# with additional symlinks to existing cursors for cursors that `Adwaita` contains, but not `phinger-cursors`.
# This is because I had regular crashes with `phinger-cursors`, due to a missing cursor, but it didn't tell me which (:.
# Errors looked like this:

# NOTE: Bug: with `phinger-cursors-light`:
# ```
# Dec 22 11:11:52 nixos-home .gnome-shell-wr[4033]: No cursor theme available, please install a cursor theme
# Dec 22 11:11:52 nixos-home .gnome-shell-wr[4033]: Received an X Window System error.
#                                                   This probably reflects a bug in the program.
#                                                   The error was 'BadCursor (invalid Cursor parameter)'.
#                                                     (Details: serial 402014 error_code 6 request_code 95 (core protocol) minor_code 0)
#                                                     (Note to programmers: normally, X errors are reported asynchronously;
#                                                      that is, you will receive the error a while after causing it.
#                                                      To debug your program, run it with the MUTTER_SYNC environment
#                                                      variable to change this behavior. You can then get a meaningful
#                                                      backtrace from your debugger if you break on the mtk_x_error() function.)
# ```
# Therefore switching to `Adwaita` for now (on this system).
# pointerCursor = {
#   package = pkgs.lib.mkForce pkgs.gnome.adwaita-icon-theme;
#   name = pkgs.lib.mkForce "Adwaita";
# };
{ lib
, runCommandLocal
, coreutils
, phinger-cursors
}:
let
  defaultCursor = "rock-n-roll";

  extraSymlinkedCursors = {
    # syntax: "link-target" = "existing-cursor-name"

    "dnd-none" = "dnd-no-drop";

    "arrow" = defaultCursor;
    "bd_double_arrow" = defaultCursor;
    "crossed_circle" = defaultCursor;
    "cross_reverse" = defaultCursor;
    "diamond_cross" = defaultCursor;
    "dnd-ask" = defaultCursor;
    "dnd-copy" = defaultCursor;
    "dnd-link" = defaultCursor;
    "dotbox" = defaultCursor;
    "dot_box_mask" = defaultCursor;
    "double_arrow" = defaultCursor;
    "draft_large" = defaultCursor;
    "draft_small" = defaultCursor;
    "draped_box" = defaultCursor;
    "e-resize" = defaultCursor;
    "fd_double_arrow" = defaultCursor;
    "grab" = defaultCursor;
    "grabbing" = defaultCursor;
    "hand" = defaultCursor;
    "h_double_arrow" = defaultCursor;
    "icon" = defaultCursor;
    "left_ptr_help" = defaultCursor;
    "left_ptr_watch" = defaultCursor;
    "link" = defaultCursor;
    "move" = defaultCursor;
    "ne-resize" = defaultCursor;
    "nesw-resize" = defaultCursor;
    "n-resize" = defaultCursor;
    "nw-resize" = defaultCursor;
    "nwse-resize" = defaultCursor;
    "pirate" = defaultCursor;
    "pointer-move" = defaultCursor;
    "sb_down_arrow" = defaultCursor;
    "sb_left_arrow" = defaultCursor;
    "sb_right_arrow" = defaultCursor;
    "se-resize" = defaultCursor;
    "size_all" = defaultCursor;
    "s-resize" = defaultCursor;
    "sw-resize" = defaultCursor;
    "target" = defaultCursor;
    "tcross" = defaultCursor;
    "top_left_arrow" = defaultCursor;
    "v_double_arrow" = defaultCursor;
    "w-resize" = defaultCursor;
    "X_cursor" = defaultCursor;
  };

  genSymlinkCursors =
    lib.concatLines (lib.mapAttrsToList
      (newCursorName: existingCursorName:
        ''ln -s "${existingCursorName}" "${newCursorName}"''
      )
      extraSymlinkedCursors);
in
runCommandLocal "phinger-cursors-extended"
{ } ''
  set -Eeuo pipefail
  set -o xtrace

  # copy all files from the original program
  cp -a --no-preserve=mode "${phinger-cursors}" "$out"

  # gen symlinks for all cursor variants (default, light), and rename them
  for cursorDir in $out/share/icons/*; do
    if [ -d "$cursorDir" ]; then
      cd "$cursorDir/cursors"
      ${genSymlinkCursors}
      mv "$cursorDir" "$cursorDir-extended"
    fi
  done
''
