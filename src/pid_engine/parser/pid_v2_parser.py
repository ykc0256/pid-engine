"""
PID V2 JSON Parser.

Parses JSON with schema_version, layout_rules, processes, instances, connections
into typed dataclasses.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class ChainItem:
    code_key: str | None = None
    item_type: str | None = None   # "TEE" or "PIPE" or None
    item_id: str | None = None


@dataclass
class Endpoint:
    instance_id: str | None = None
    ref_id: str | None = None
    port: int | None = None
    chain: list[ChainItem] = field(default_factory=list)

    @property
    def is_ref(self) -> bool:
        return self.ref_id is not None


@dataclass
class PIDProcess:
    id: str
    name: str
    order: int


@dataclass
class PIDInstance:
    id: str
    code_key: str
    instance_type: str
    process_id: str
    media: list[str]
    series_id: str | None
    location_type: str
    parent_structure: str | None
    inside_slot: str | None


@dataclass
class PIDConnection:
    id: str
    media: str
    line_class: str
    size: str
    from_ep: Endpoint
    to_ep: Endpoint
    chain: list[ChainItem] = field(default_factory=list)


@dataclass
class LayoutRules:
    process_direction: str
    lane_order: list[str]


@dataclass
class PIDData:
    schema_version: str
    layout_rules: LayoutRules
    processes: list[PIDProcess]
    instances: list[PIDInstance]
    connections: list[PIDConnection]


def _parse_chain_items(items: list[dict]) -> list[ChainItem]:
    result = []
    for item in items:
        if "type" in item and item["type"] == "TEE":
            result.append(ChainItem(
                item_type="TEE",
                item_id=item.get("id"),
            ))
        elif "code_key" in item:
            result.append(ChainItem(
                code_key=item["code_key"],
                item_type="PIPE",
            ))
        else:
            result.append(ChainItem())
    return result


def _parse_endpoint(ep_data: dict) -> Endpoint:
    if "ref" in ep_data:
        return Endpoint(ref_id=ep_data["ref"])

    chain_items = _parse_chain_items(ep_data.get("chain", []))
    return Endpoint(
        instance_id=ep_data.get("id"),
        port=ep_data.get("port"),
        chain=chain_items,
    )


class PIDV2Parser:
    def parse_file(self, path: str | Path) -> PIDData:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return self._parse(data)

    def parse_string(self, text: str) -> PIDData:
        data = json.loads(text)
        return self._parse(data)

    def _parse(self, data: dict) -> PIDData:
        layout_raw = data.get("layout_rules", {})
        layout_rules = LayoutRules(
            process_direction=layout_raw.get("process_direction", "LEFT_TO_RIGHT"),
            lane_order=layout_raw.get("lane_order", []),
        )

        processes = [
            PIDProcess(
                id=p["id"],
                name=p.get("name", ""),
                order=p.get("order", 0),
            )
            for p in data.get("processes", [])
        ]

        instances = []
        for inst in data.get("instances", []):
            instances.append(PIDInstance(
                id=inst["id"],
                code_key=inst.get("code_key", ""),
                instance_type=inst.get("instance_type", ""),
                process_id=inst.get("process_id", ""),
                media=inst.get("media", []),
                series_id=inst.get("series_id"),
                location_type=inst.get("location_type", ""),
                parent_structure=inst.get("parent_structure"),
                inside_slot=inst.get("inside_slot"),
            ))

        connections = []
        for conn in data.get("connections", []):
            from_ep = _parse_endpoint(conn.get("from", {}))
            to_ep = _parse_endpoint(conn.get("to", {}))
            chain = _parse_chain_items(conn.get("chain", []))
            connections.append(PIDConnection(
                id=conn["id"],
                media=conn.get("media", ""),
                line_class=conn.get("line_class", ""),
                size=conn.get("size", ""),
                from_ep=from_ep,
                to_ep=to_ep,
                chain=chain,
            ))

        return PIDData(
            schema_version=data.get("schema_version", "PID_TEST_V2"),
            layout_rules=layout_rules,
            processes=processes,
            instances=instances,
            connections=connections,
        )
