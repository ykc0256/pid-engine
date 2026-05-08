"""
PID V2 LISP Code Generator.

Reads PIDData (from PIDV2Parser) and outputs a complete AutoCAD LISP script.

The static utility functions are extracted from a reference .lsp file so the
generated file uses exactly the same runtime.  Only the two generated sections
(pid-create-test-connections and c:PID_LAYOUT_TEST) are produced programmatically.
"""
from __future__ import annotations

import re
from pathlib import Path

from ..parser.pid_v2_parser import (
    PIDData,
    PIDInstance,
    PIDConnection,
    Endpoint,
    ChainItem,
)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _chain_has_tee(chain: list[ChainItem]) -> bool:
    return any(item.item_type == "TEE" for item in chain)


def _tee_id_from_chain(chain: list[ChainItem]) -> str | None:
    for item in chain:
        if item.item_type == "TEE":
            return item.item_id
    return None


def _chain_to_lisp(chain: list[ChainItem]) -> str:
    """Convert endpoint chain items to a LISP list or nil."""
    codes = [item.code_key for item in chain if item.code_key and item.item_type != "TEE"]
    if not codes:
        return "nil"
    items = " ".join(f'"{c}"' for c in codes)
    return f"(list {items})"


def _ep_chain_to_lisp(ep: Endpoint) -> str:
    """Convert endpoint's own chain list to a LISP list or nil."""
    return _chain_to_lisp(ep.chain)


# ---------------------------------------------------------------------------
# Template extraction
# ---------------------------------------------------------------------------

def _find_matching_close(lines: list[str], start_idx: int) -> int:
    """
    Starting from start_idx (the line containing the opening defun),
    count parens and return the index of the line that closes the defun.

    Ignores characters after a semicolon (AutoLISP comment syntax).
    Also handles string literals by not counting parens inside double-quoted strings.
    """
    depth = 0
    for i in range(start_idx, len(lines)):
        line = lines[i]
        in_string = False
        for ch in line:
            if ch == ";":
                if not in_string:
                    break  # rest of line is a comment
            elif ch == '"':
                in_string = not in_string
            elif not in_string:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        return i
    return len(lines) - 1


def _extract_template_from_reference(reference_path: Path) -> tuple[str, str, str]:
    """
    Extract three sections from the reference .lsp file:

    1. before_connections : everything before (defun pid-create-test-connections
    2. between_functions  : lines between the end of pid-create-test-connections
                            and the start of (defun c:PID_LAYOUT_TEST
    3. after_layout       : everything after the end of c:PID_LAYOUT_TEST

    Returns (before_connections, between_functions, after_layout) as strings.
    """
    text = reference_path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Find pid-create-test-connections
    conn_start = None
    for i, line in enumerate(lines):
        if "(defun pid-create-test-connections" in line:
            conn_start = i
            break
    if conn_start is None:
        raise ValueError("Could not find (defun pid-create-test-connections in reference file")

    conn_end = _find_matching_close(lines, conn_start)

    # Find c:PID_LAYOUT_TEST  (must appear after conn_end)
    layout_start = None
    for i in range(conn_end + 1, len(lines)):
        if "(defun c:PID_LAYOUT_TEST" in lines[i]:
            layout_start = i
            break
    if layout_start is None:
        raise ValueError("Could not find (defun c:PID_LAYOUT_TEST in reference file")

    layout_end = _find_matching_close(lines, layout_start)

    before_connections = "".join(lines[:conn_start])
    between_functions = "".join(lines[conn_end + 1 : layout_start])
    after_layout = "".join(lines[layout_end + 1 :])

    return before_connections, between_functions, after_layout


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------

class PIDV2Generator:
    def __init__(self, reference_lsp_path: Path | str | None = None):
        self._reference_lsp_path = Path(reference_lsp_path) if reference_lsp_path else None

    # ------------------------------------------------------------------
    # Public entry point
    # ------------------------------------------------------------------

    def generate(self, pid_data: PIDData) -> str:
        if self._reference_lsp_path is None or not self._reference_lsp_path.exists():
            raise FileNotFoundError(
                f"Reference LSP file not found: {self._reference_lsp_path}"
            )

        before_conn, between_funcs, after_layout = _extract_template_from_reference(
            self._reference_lsp_path
        )

        # Replace the pid-inside-parent-id function body in before_conn
        before_conn = self._replace_inside_parent_id(before_conn, pid_data)

        # Replace the pid-draw-layout-guide function body in before_conn
        before_conn = self._replace_layout_guide(before_conn, pid_data)

        connections_body = self._generate_connections(pid_data)
        layout_body = self._generate_layout_test(pid_data)

        # Build the full pid-create-test-connections defun
        conn_defun = self._build_conn_defun(pid_data, connections_body)

        # Build the full c:PID_LAYOUT_TEST defun
        layout_defun = self._build_layout_defun(layout_body)

        parts = [
            before_conn,
            conn_defun,
            between_funcs,
            layout_defun,
            after_layout,
        ]
        return "".join(parts)

    # ------------------------------------------------------------------
    # pid-inside-parent-id generation
    # ------------------------------------------------------------------

    def _replace_inside_parent_id(self, source: str, pid_data: PIDData) -> str:
        """Replace the hardcoded pid-inside-parent-id function with a generated one."""
        lines = source.splitlines(keepends=True)

        func_start = None
        for i, line in enumerate(lines):
            if "(defun pid-inside-parent-id" in line:
                func_start = i
                break
        if func_start is None:
            return source  # not found – leave as-is

        func_end = _find_matching_close(lines, func_start)

        new_func = self._generate_inside_parent_id_func(pid_data)
        result = (
            "".join(lines[:func_start])
            + new_func
            + "\n"
            + "".join(lines[func_end + 1 :])
        )
        return result

    def _generate_inside_parent_id_func(self, pid_data: PIDData) -> str:
        """
        Generate:
          (defun pid-inside-parent-id (id / u)
            (setq u (strcase id))
            (cond
              ((or (= u "X") (= u "Y")) "PARENT")
              ...
              (T nil)
            )
          )
        """
        # Group inside-structure machines by parent_structure
        parent_map: dict[str, list[str]] = {}  # parent_id -> [child_id, ...]
        for inst in pid_data.instances:
            if inst.location_type == "INSIDE_STRUCTURE" and inst.parent_structure:
                parent_map.setdefault(inst.parent_structure, []).append(inst.id)

        lines = []
        lines.append("(defun pid-inside-parent-id (id / u)\n")
        lines.append("  ;; Generated from JSON: parent_structure field.\n")
        lines.append("  (setq u (strcase id))\n")
        lines.append("  (cond\n")
        for parent_id, child_ids in parent_map.items():
            conds = " ".join(f'(= u "{cid.upper()}")' for cid in child_ids)
            if len(child_ids) == 1:
                lines.append(f'    ((= u "{child_ids[0].upper()}") "{parent_id}")\n')
            else:
                lines.append(f'    ((or {conds}) "{parent_id}")\n')
        lines.append("    (T nil)\n")
        lines.append("  )\n")
        lines.append(")")
        return "".join(lines)

    # ------------------------------------------------------------------
    # pid-draw-layout-guide generation
    # ------------------------------------------------------------------

    def _replace_layout_guide(self, source: str, pid_data: PIDData) -> str:
        """
        The reference file already has a correct pid-draw-layout-guide for this
        exact JSON.  We leave it untouched – the template extraction already
        carries it verbatim.  This method is a no-op placeholder for future
        extension.
        """
        return source

    # ------------------------------------------------------------------
    # pid-create-test-connections
    # ------------------------------------------------------------------

    def _build_conn_defun(self, pid_data: PIDData, body: str) -> str:
        """Wrap the connection body in a defun with the correct local variables."""
        # Collect all trunk variable names that will be used
        trunk_vars = self._collect_trunk_vars(pid_data)
        if trunk_vars:
            var_list = " ".join(trunk_vars)
            header = f"(defun pid-create-test-connections (/ {var_list})\n"
        else:
            header = "(defun pid-create-test-connections (/)\n"

        return (
            header
            + "  (pid-layer \"PID_PIPE\" 1)\n"
            + "  (pid-layer \"PID_CHAIN\" 5)\n"
            + "  (pid-layer \"PID_REF\" 6)\n"
            + "  (setq *PID-PIPE-SEGMENTS* nil)\n"
            + "  (setq *PID-REF-MAP* nil)\n"
            + "\n"
            + body
            + "\n)\n"
        )

    def _collect_trunk_vars(self, pid_data: PIDData) -> list[str]:
        """Return the list of local variable names needed for trunk pre-computations."""
        vars_list = []
        trunk_conns = self._find_trunk_connections(pid_data.connections)
        for conn in trunk_conns:
            mid_tee_id = _tee_id_from_chain(conn.chain)
            if not mid_tee_id:
                continue
            var_prefix = mid_tee_id.lower()
            trunk_path_var = self._trunk_path_var(conn)
            if trunk_path_var and trunk_path_var not in vars_list:
                vars_list.append(trunk_path_var)
            sibling = self._find_sibling_connection(conn, pid_data.connections)
            if sibling:
                info_var = f"{var_prefix}-info"
                target_var = f"{var_prefix}-target"
                if info_var not in vars_list:
                    vars_list.append(info_var)
                if target_var not in vars_list:
                    vars_list.append(target_var)
        return vars_list

    # ------------------------------------------------------------------
    # Connection generation
    # ------------------------------------------------------------------

    def _generate_connections(self, pid_data: PIDData) -> str:
        """
        Generate all connection calls in strict JSON order.

        Trunk connections emit only the pre-computation block (setq info/target,
        trunk path, tee-on-path).  The sibling connection is emitted when it
        appears in JSON order using the pre-computed variables.
        """
        lines = []

        # Build inside-structure set for SOURCE_NEAR detection
        inside_ids = {
            inst.id
            for inst in pid_data.instances
            if inst.location_type == "INSIDE_STRUCTURE"
        }

        # Build sibling map: sibling_conn_id -> trunk_conn
        sibling_to_trunk: dict[str, PIDConnection] = {}
        for conn in pid_data.connections:
            sibling = self._find_sibling_connection(conn, pid_data.connections)
            if sibling:
                sibling_to_trunk[sibling.id] = conn

        # Build trunk pre-computation info keyed by trunk conn id
        # Maps trunk_conn_id -> (info_var, trunk_path_var, sib_is_ref_to_ep,
        #                         sib_id, sib_port, sib_chain_lisp, mid_tee_id)
        trunk_info: dict[str, dict] = {}
        for conn in pid_data.connections:
            if self._classify_connection(conn) == "TRUNK":
                mid_tee_id = _tee_id_from_chain(conn.chain)
                if not mid_tee_id:
                    continue
                var_prefix = mid_tee_id.lower()
                sibling = self._find_sibling_connection(conn, pid_data.connections)
                sib_is_ref_to_ep = False
                sib_id = None
                sib_port = None
                sib_chain_lisp = "nil"
                if sibling:
                    if sibling.from_ep.is_ref and not sibling.to_ep.is_ref:
                        sib_is_ref_to_ep = True
                        sib_id = sibling.to_ep.instance_id
                        sib_port = sibling.to_ep.port
                        sib_chain_lisp = _ep_chain_to_lisp(sibling.to_ep)
                    else:
                        sib_is_ref_to_ep = False
                        sib_id = sibling.from_ep.instance_id
                        sib_port = sibling.from_ep.port
                        sib_chain_lisp = _ep_chain_to_lisp(sibling.from_ep)
                trunk_info[conn.id] = {
                    "mid_tee_id": mid_tee_id,
                    "var_prefix": var_prefix,
                    "info_var": f"{var_prefix}-info",
                    "target_var": f"{var_prefix}-target",
                    "trunk_path_var": self._trunk_path_var(conn),
                    "sibling": sibling,
                    "sib_is_ref_to_ep": sib_is_ref_to_ep,
                    "sib_id": sib_id,
                    "sib_port": sib_port,
                    "sib_chain_lisp": sib_chain_lisp,
                }

        current_media = None

        for conn in pid_data.connections:
            media = conn.media

            # Media switch
            if media != current_media:
                lines.append(f"\n  ;; {'=' * 60}\n")
                lines.append(f"  ;; {media}\n")
                lines.append(f"  ;; {'=' * 60}\n")
                lines.append(f'  (pid-set-current-media "{media}")\n')
                current_media = media

            conn_type = self._classify_connection(conn)

            if conn_type == "TRUNK":
                # Emit only pre-computation + trunk path + tee creation
                ti = trunk_info.get(conn.id)
                if ti:
                    self._gen_trunk_precomp(conn, ti, lines, media)

            elif conn.id in sibling_to_trunk:
                # This connection is the sibling of a trunk.
                # Use pre-computed variables instead of inline endpoint-info.
                trunk_conn = sibling_to_trunk[conn.id]
                ti = trunk_info.get(trunk_conn.id)
                if ti:
                    self._gen_sibling_conn(conn, ti, lines, media)
                else:
                    # Fallback: emit normally
                    self._gen_single_conn(conn, conn_type, lines, inside_ids)
            else:
                self._gen_single_conn(conn, conn_type, lines, inside_ids)

        return "".join(lines)

    def _classify_connection(self, conn: PIDConnection) -> str:
        from_ref = conn.from_ep.is_ref
        to_ref = conn.to_ep.is_ref
        has_main_tee = _chain_has_tee(conn.chain)

        if from_ref and to_ref and has_main_tee:
            return "TRUNK"
        if from_ref and to_ref and not has_main_tee:
            return "SEGMENT"
        if from_ref and not to_ref:
            return "REF_TO_EP"
        if not from_ref and to_ref and not has_main_tee:
            return "EP_TO_REF"
        if not from_ref and not to_ref and has_main_tee:
            return "EP_WITH_TEE"
        # Simple: not from_ref, not to_ref, no main chain TEE
        return "SIMPLE"

    # ------------------------------------------------------------------
    # Trunk handler
    # ------------------------------------------------------------------

    def _find_trunk_connections(self, connections: list[PIDConnection]) -> list[PIDConnection]:
        return [c for c in connections if self._classify_connection(c) == "TRUNK"]

    def _find_sibling_connection(
        self,
        trunk_conn: PIDConnection,
        all_connections: list[PIDConnection],
    ) -> PIDConnection | None:
        """
        Find the connection whose real endpoint uses the trunk's mid-TEE as its ref.
        A sibling has:
          - from_ep.ref_id == mid_tee_id  OR  to_ep.ref_id == mid_tee_id
          - AND the other endpoint is a real instance (not a ref)
          - AND it is NOT itself a trunk connection
        """
        mid_tee_id = _tee_id_from_chain(trunk_conn.chain)
        if not mid_tee_id:
            return None

        for conn in all_connections:
            if conn.id == trunk_conn.id:
                continue
            if self._classify_connection(conn) == "TRUNK":
                continue
            # from is ref to mid_tee, to is instance
            if conn.from_ep.is_ref and conn.from_ep.ref_id == mid_tee_id and not conn.to_ep.is_ref:
                return conn
            # to is ref to mid_tee, from is instance
            if conn.to_ep.is_ref and conn.to_ep.ref_id == mid_tee_id and not conn.from_ep.is_ref:
                return conn
        return None

    def _trunk_path_var(self, trunk_conn: PIDConnection) -> str | None:
        """Variable name for the virtual trunk path for this trunk connection."""
        mid_tee_id = _tee_id_from_chain(trunk_conn.chain)
        if not mid_tee_id:
            return None
        # Use a descriptive name based on tee id
        return f"{mid_tee_id.lower().replace('-', '_')}-trunk-path"

    def _gen_trunk_precomp(
        self,
        trunk_conn: PIDConnection,
        ti: dict,
        lines: list[str],
        media: str,
    ) -> None:
        """
        Emit the pre-computation block for a trunk connection:
          - setq info_var / target_var (if sibling exists)
          - setq trunk_path_var = pid-connect-ref-to-ref-virtual-path
          - pid-create-tee-on-path
        Does NOT emit the sibling connection call (that is emitted in JSON order).
        """
        mid_tee_id = ti["mid_tee_id"]
        from_ref = trunk_conn.from_ep.ref_id
        to_ref = trunk_conn.to_ep.ref_id
        info_var = ti["info_var"]
        target_var = ti["target_var"]
        trunk_path_var = ti["trunk_path_var"]
        sibling = ti["sibling"]
        sib_id = ti["sib_id"]
        sib_port = ti["sib_port"]
        sib_chain_lisp = ti["sib_chain_lisp"]

        lines.append(f"\n  ;; {trunk_conn.id}\n")
        lines.append(f"  ;; {media}\n")
        lines.append(f"  ;; {from_ref} -> {mid_tee_id} -> {to_ref}\n")

        if sibling:
            lines.append(f"  ;; Pre-compute sibling endpoint for TEE alignment\n")
            lines.append(f"  (setq {info_var}\n")
            if sib_chain_lisp == "nil":
                lines.append(
                    f'    (pid-endpoint-info-safe "{sib_id}" {sib_port} nil)\n'
                )
            else:
                lines.append(
                    f'    (pid-endpoint-info-safe "{sib_id}" {sib_port}\n'
                )
                lines.append(f'      {sib_chain_lisp}\n')
                lines.append(f"    )\n")
            lines.append(f"  )\n")
            lines.append(f"  (setq {target_var} (cadr {info_var}))\n")
            lines.append("\n")

        lines.append(f"  ;; trunk calculation only, no trunk pipe output\n")
        lines.append(
            f'  (setq {trunk_path_var} (pid-connect-ref-to-ref-virtual-path "{from_ref}" "{to_ref}"))\n'
        )
        if sibling:
            lines.append(
                f'  (pid-create-tee-on-path "{mid_tee_id}" {trunk_path_var} {target_var})\n'
            )
        else:
            lines.append(
                f'  (pid-create-tee-on-path "{mid_tee_id}" {trunk_path_var} nil)\n'
            )

    def _gen_sibling_conn(
        self,
        conn: PIDConnection,
        ti: dict,
        lines: list[str],
        media: str,
    ) -> None:
        """Emit a sibling connection call using pre-computed trunk variables."""
        mid_tee_id = ti["mid_tee_id"]
        info_var = ti["info_var"]
        sib_is_ref_to_ep = ti["sib_is_ref_to_ep"]
        sib_id = ti["sib_id"]
        sib_port = ti["sib_port"]

        lines.append(f"\n  ;; {conn.id}\n")
        lines.append(f"  ;; {media}\n")

        if sib_is_ref_to_ep:
            lines.append(f"  ;; {mid_tee_id} -> {sib_id} port{sib_port} (pre-computed)\n")
            lines.append(f"  (pid-connect-ref-to-endinfo\n")
            lines.append(f'    "{conn.id}"\n')
            lines.append(f'    "{mid_tee_id}"\n')
            lines.append(f"    {info_var}\n")
            lines.append(f"  )\n")
        else:
            lines.append(f"  ;; {sib_id} port{sib_port} (pre-computed) -> {mid_tee_id}\n")
            lines.append(f"  (pid-connect-endinfo-to-ref\n")
            lines.append(f'    "{conn.id}"\n')
            lines.append(f"    {info_var}\n")
            lines.append(f'    "{mid_tee_id}"\n')
            lines.append(f"  )\n")

    # ------------------------------------------------------------------
    # Single connection generator
    # ------------------------------------------------------------------

    def _gen_single_conn(
        self,
        conn: PIDConnection,
        conn_type: str,
        lines: list[str],
        inside_ids: set[str],
    ) -> None:
        from_ep = conn.from_ep
        to_ep = conn.to_ep

        lines.append(f"\n  ;; {conn.id}\n")
        lines.append(f"  ;; {conn.media}\n")

        if conn_type == "SEGMENT":
            # ref -> chain items -> ref
            chain_lisp = _chain_to_lisp(conn.chain)
            from_ref = from_ep.ref_id
            to_ref = to_ep.ref_id
            lines.append(f"  ;; {from_ref} -> chain -> {to_ref}\n")
            lines.append(f"  (pid-connect-ref-to-ref-with-centered-chain\n")
            lines.append(f'    "{conn.id}"\n')
            lines.append(f'    "{from_ref}"\n')
            lines.append(f'    "{to_ref}"\n')
            lines.append(f"    {chain_lisp}\n")
            lines.append(f"  )\n")

        elif conn_type == "REF_TO_EP":
            ref_id = from_ep.ref_id
            to_id = to_ep.instance_id
            to_port = to_ep.port
            to_chain_lisp = _ep_chain_to_lisp(to_ep)
            lines.append(f"  ;; {ref_id} -> {to_id} port{to_port}\n")
            if to_chain_lisp == "nil":
                lines.append(f"  (pid-connect-ref-to-endinfo\n")
                lines.append(f'    "{conn.id}"\n')
                lines.append(f'    "{ref_id}"\n')
                lines.append(
                    f'    (pid-endpoint-info-safe "{to_id}" {to_port} nil)\n'
                )
                lines.append(f"  )\n")
            else:
                lines.append(f"  (pid-connect-ref-to-endinfo\n")
                lines.append(f'    "{conn.id}"\n')
                lines.append(f'    "{ref_id}"\n')
                lines.append(f'    (pid-endpoint-info-safe "{to_id}" {to_port}\n')
                lines.append(f"      {to_chain_lisp}\n")
                lines.append(f"    )\n")
                lines.append(f"  )\n")

        elif conn_type == "EP_TO_REF":
            from_id = from_ep.instance_id
            from_port = from_ep.port
            from_chain_lisp = _ep_chain_to_lisp(from_ep)
            ref_id = to_ep.ref_id
            lines.append(f"  ;; {from_id} port{from_port} -> {ref_id}\n")
            if from_chain_lisp == "nil":
                lines.append(f"  (pid-connect-endinfo-to-ref\n")
                lines.append(f'    "{conn.id}"\n')
                lines.append(
                    f'    (pid-endpoint-info-safe "{from_id}" {from_port} nil)\n'
                )
                lines.append(f'    "{ref_id}"\n')
                lines.append(f"  )\n")
            else:
                lines.append(f"  (pid-connect-endinfo-to-ref\n")
                lines.append(f'    "{conn.id}"\n')
                lines.append(f'    (pid-endpoint-info-safe "{from_id}" {from_port}\n')
                lines.append(f"      {from_chain_lisp}\n")
                lines.append(f"    )\n")
                lines.append(f'    "{ref_id}"\n')
                lines.append(f"  )\n")

        elif conn_type == "EP_WITH_TEE":
            from_id = from_ep.instance_id
            from_port = from_ep.port
            from_chain_lisp = _ep_chain_to_lisp(from_ep)
            to_id = to_ep.instance_id
            to_port = to_ep.port
            to_chain_lisp = _ep_chain_to_lisp(to_ep)
            tee_id = _tee_id_from_chain(conn.chain)
            lines.append(f"  ;; {from_id} port{from_port} [TEE:{tee_id}] {to_id} port{to_port}\n")
            lines.append(f"  (pid-connect-endpoints-with-tee\n")
            lines.append(f'    "{conn.id}"\n')
            lines.append(f'    "{from_id}" {from_port} {from_chain_lisp}\n')
            lines.append(f'    "{tee_id}"\n')
            lines.append(f'    "{to_id}" {to_port} {to_chain_lisp}\n')
            lines.append(f"  )\n")

        elif conn_type == "SIMPLE":
            from_id = from_ep.instance_id
            from_port = from_ep.port
            from_chain_lisp = _ep_chain_to_lisp(from_ep)
            to_id = to_ep.instance_id
            to_port = to_ep.port
            to_chain_lisp = _ep_chain_to_lisp(to_ep)
            lines.append(f"  ;; {from_id} port{from_port} -> {to_id} port{to_port}\n")

            # SOURCE_NEAR preference for INSIDE_STRUCTURE from-endpoint
            if from_id in inside_ids:
                lines.append(f"  (pid-connect-endpoints-pref\n")
                lines.append(f'    "SOURCE_NEAR"\n')
                lines.append(f'    "{conn.id}"\n')
                lines.append(f'    "{from_id}" {from_port} {from_chain_lisp}\n')
                lines.append(f'    "{to_id}" {to_port} {to_chain_lisp}\n')
                lines.append(f"  )\n")
            else:
                lines.append(f"  (pid-connect-endpoints\n")
                lines.append(f'    "{conn.id}"\n')
                lines.append(f'    "{from_id}" {from_port} {from_chain_lisp}\n')
                lines.append(f'    "{to_id}" {to_port} {to_chain_lisp}\n')
                lines.append(f"  )\n")

        else:
            lines.append(f"  ;; UNHANDLED connection type: {conn_type}\n")

    # ------------------------------------------------------------------
    # c:PID_LAYOUT_TEST generation
    # ------------------------------------------------------------------

    def _generate_layout_test(self, pid_data: PIDData) -> str:
        lines = []

        # Build process order map
        proc_order: dict[str, int] = {p.id: p.order for p in pid_data.processes}

        # Separate structures, inside machines, outside machines
        structures = [i for i in pid_data.instances if i.instance_type == "STRUCTURE"]
        inside_machines = [
            i for i in pid_data.instances if i.location_type == "INSIDE_STRUCTURE"
        ]
        outside_machines = [
            i for i in pid_data.instances if i.location_type == "OUTSIDE_STRUCTURE"
        ]

        # Sort structures: by process order, then by appearance index in instances list
        instance_index = {inst.id: idx for idx, inst in enumerate(pid_data.instances)}
        structures_sorted = sorted(
            structures,
            key=lambda s: (proc_order.get(s.process_id, 999), instance_index[s.id]),
        )

        # Structures placement
        lines.append("  ;; 1) Structures\n")

        # Group structures by process
        proc_structs: dict[str, list[PIDInstance]] = {}
        for s in structures_sorted:
            proc_structs.setdefault(s.process_id, []).append(s)

        proc_ids_sorted = sorted(proc_structs.keys(), key=lambda p: proc_order.get(p, 999))

        for proc_id in proc_ids_sorted:
            order = proc_order.get(proc_id, 1)
            proc_s_list = proc_structs[proc_id]
            lines.append(f"  ;; {proc_id} structures\n")
            for idx, s in enumerate(proc_s_list):
                if order == 1:
                    lines.append(
                        f'  (pid-place-structure "{s.id}" "{s.code_key}" {idx})\n'
                    )
                else:
                    x = 1530.0 * (order - 1)
                    y = 0.0
                    lines.append(
                        f'  (pid-place-structure-at "{s.id}" "{s.code_key}" {x:.1f} {y:.1f})\n'
                    )

        # Inside machines – group by parent structure
        lines.append("\n  ;; 2) Inside machines\n")
        # Group by parent to emit together
        parent_groups: dict[str, list[PIDInstance]] = {}
        for m in inside_machines:
            parent_groups.setdefault(m.parent_structure or "", []).append(m)

        for s in structures_sorted:
            children = parent_groups.get(s.id, [])
            if children:
                lines.append(f"  ;; {s.id}\n")
                for m in children:
                    slot = m.inside_slot or "INSIDE1"
                    lines.append(
                        f'  (pid-place-inside-machine "{m.id}" "{m.code_key}" "{s.id}" "{slot}")\n'
                    )

        # Outside machines
        lines.append("\n  ;; 3) Outside machines\n")
        for m in outside_machines:
            media = m.media[0] if m.media else "UNKNOWN"
            series = m.series_id or ""
            lines.append(
                f'  (pid-place-lane-machine-auto "{m.id}" "{m.code_key}" "{media}" "{series}")\n'
            )

        # Connections call
        lines.append("\n  ;; 4) Rule-based connections\n")
        lines.append("  (pid-create-test-connections)\n")

        return "".join(lines)

    def _build_layout_defun(self, body: str) -> str:
        return (
            "(defun c:PID_LAYOUT_TEST (/ oldattdia oldattreq oldcmdecho oldosmode)\n"
            "  (setq oldattdia (getvar \"ATTDIA\"))\n"
            "  (setq oldattreq (getvar \"ATTREQ\"))\n"
            "  (setq oldcmdecho (getvar \"CMDECHO\"))\n"
            "  (setq oldosmode (getvar \"OSMODE\"))\n"
            "\n"
            "  (setvar \"CMDECHO\" 0)\n"
            "  (setvar \"ATTDIA\" 0)\n"
            "  (setvar \"ATTREQ\" 0)\n"
            "  (setvar \"OSMODE\" 0)\n"
            "\n"
            "  (setq *PID-INSTANCE-MAP* nil)\n"
            "  (setq *PID-SERIES-STATE* nil)\n"
            "\n"
            "  (pid-layer \"PID_PROCESS_AREA\" 8)\n"
            "  (pid-layer \"PID_LANE\" 8)\n"
            "  (pid-layer \"PID_LANE_RAW_WATER\" 1)\n"
            "  (pid-layer \"PID_STRUCTURE\" 2)\n"
            "  (pid-layer \"PID_INSIDE_MACHINE\" 4)\n"
            "  (pid-layer \"PID_OUTSIDE_MACHINE\" 3)\n"
            "  (pid-layer \"PID_INSERT_MARK\" 1)\n"
            "  (pid-layer \"PID_LABEL\" 7)\n"
            "  (pid-layer \"PID_PIPE\" 1)\n"
            "  (pid-layer \"PID_CHAIN\" 5)\n"
            "\n"
            "  (pid-draw-layout-guide)\n"
            "\n"
            + body
            + "\n"
            "  (setvar \"ATTDIA\" oldattdia)\n"
            "  (setvar \"ATTREQ\" oldattreq)\n"
            "  (setvar \"OSMODE\" oldosmode)\n"
            "  (setvar \"CMDECHO\" oldcmdecho)\n"
            "\n"
            "  (prompt \"\\n[PID] PID V2 generated layout completed. Command: PID_LAYOUT_TEST\")\n"
            "  (princ)\n"
            ")\n"
        )
