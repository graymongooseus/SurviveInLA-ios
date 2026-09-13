#!/usr/bin/env python3
"""Validate the shipped event pack; optionally regenerate its author-facing index."""
import argparse
import json
import math
import re
from pathlib import Path


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load(path):
    try:
        return json.loads(path.read_text(), object_pairs_hook=unique_keys)
    except (OSError, ValueError) as error:
        raise ValueError(f"{path}: {error}") from error


def require(ok, where, message):
    if not ok:
        raise ValueError(f"{where}: {message}")


def fields(value, allowed, required, where):
    require(isinstance(value, dict), where, "expected object")
    require(not (set(value) - set(allowed)), where, f"unknown fields: {set(value) - set(allowed)}")
    require(set(required) <= set(value), where, f"missing fields: {set(required) - set(value)}")


def number(value, lower, upper, where, integer=False):
    require(type(value) in (int, float) and math.isfinite(value), where, "expected finite number")
    require(lower <= value <= upper and (not integer or type(value) is int), where, "out of range or incorrect numeric type")


def weight(value, where):
    fields(value, ["baseWeight", "favorability", "strength"], ["baseWeight", "favorability", "strength"], where)
    number(value["baseWeight"], 0, 10000, where)
    number(value["strength"], 1, 3, where, integer=True)
    require(value["favorability"] in ["favorable", "mixed", "unfavorable"], where, "invalid favorability")


def condition(value, where, world_ids, choices, district_ids, depth=0):
    require(depth < 32, where, "condition nesting exceeds 32 levels")
    require(isinstance(value, dict) and len(value) == 1, where, "condition must have one tagged case")
    kind, args = next(iter(value.items()))
    if kind in ("all", "any", "not"):
        arg_key = "condition" if kind == "not" else "conditions"
        fields(args, [arg_key], [arg_key], where)
        children = [args[arg_key]] if kind == "not" else args[arg_key]
        require(isinstance(children, list), where, "expected condition array")
        for index, child in enumerate(children):
            condition(child, f"{where}.{kind}[{index}]", world_ids, choices, district_ids, depth + 1)
    elif kind == "metric":
        fields(args, ["name", "comparison", "value"], ["name", "comparison", "value"], where)
        require(args["name"] in ["week", "cash", "bank", "debt", "health", "luck", "availableCapacity"], where, "unknown metric")
        require(args["comparison"] in ["equal", "atLeast", "atMost", "greaterThan"], where, "unknown comparison")
        number(args["value"], -1000000000, 1000000000, where, integer=True)
    elif kind == "choiceSelected":
        fields(args, ["eventID", "optionID"], ["eventID", "optionID"], where)
        require(args["eventID"] in choices and args["optionID"] in choices[args["eventID"]], where, "unknown choice/option reference")
    else:
        arg_key = "item" if kind == "equipment" else "id"
        fields(args, [arg_key], [arg_key], where)
        if kind == "worldEventActive":
            require(args[arg_key] in world_ids, where, "unknown world event reference")
        elif kind == "choiceResolved":
            require(args[arg_key] in choices, where, "unknown life choice reference")
        elif kind == "equipment":
            require(args[arg_key] in ["housing", "vehicle", "activeDriversLicense", "tools", "property", "hope"], where, "unknown equipment")
        elif kind == "district":
            require(args[arg_key] in district_ids, where, "invalid district ID")
        else:
            raise ValueError(f"{where}: unknown condition case {kind}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--export-catalog", action="store_true")
    parser.add_argument("--data-only", action="store_true", help="Explicitly skip artwork checks when validating a source-only checkout")
    parser.add_argument("--world-weights", type=int, metavar="LUCK")
    args = parser.parse_args()
    root = args.root.resolve()
    content = root / "SurviveInLA/Resources/Content"
    model_source = (root / "SurviveInLA/Domain/GameModels.swift").read_text()

    def enum_ids(name):
        block = model_source.split(f"struct {name}:", 1)[1].split("enum ID:", 1)[1].split("\n    }", 1)[0]
        return set(re.findall(r"^        case ([a-zA-Z0-9_]+)$", block, re.MULTILINE))

    commodity_ids, district_ids = enum_ids("Commodity"), enum_ids("District")
    manifest = load(content / "manifest.json")
    fields(manifest, ["schemaVersion", "contentVersion", "localeFile", "locationFiles", "worldFiles", "lifeChoiceFiles", "investmentEventFiles", "celebrityFiles", "celebrityPhotoEventFiles", "celebrityActingEventFiles", "worldSchedule", "lifeChoiceStages"], ["schemaVersion", "contentVersion", "localeFile", "locationFiles", "worldFiles", "lifeChoiceFiles", "worldSchedule", "lifeChoiceStages"], "manifest")
    require(manifest["schemaVersion"] == 1, "manifest", "unsupported schema")

    def content_path(name):
        path = (content / name).resolve()
        require(path.is_relative_to(content.resolve()), name, "path escapes content directory")
        return path

    strings = load(content_path(manifest["localeFile"]))
    schedule = manifest["worldSchedule"]
    fields(schedule, ["firstWeek", "intervalWeeks", "occurrenceChance", "luckScale"], ["firstWeek", "intervalWeeks", "occurrenceChance", "luckScale"], "worldSchedule")
    number(schedule["firstWeek"], 1, 52, "worldSchedule", integer=True)
    number(schedule["intervalWeeks"], 1, 52, "worldSchedule", integer=True)
    number(schedule["occurrenceChance"], 0, 1, "worldSchedule")
    number(schedule["luckScale"], 1, 10, "worldSchedule")
    entries = []
    for family in ("location", "world", "lifeChoice", "investmentEvent", "celebrityPhotoEvent", "celebrityActingEvent"):
        for filename in manifest.get(family + "Files", []):
            for entry in load(content_path(filename)):
                entries.append((family, filename, entry))
    ids = [e["id"] for _, _, e in entries]
    require(all(isinstance(i, str) and i for i in ids) and len(set(ids)) == len(ids), "catalog", "duplicate or empty event ID")
    world_ids = {e["id"] for family, _, e in entries if family == "world"}
    choices = {e["id"]: {o["id"] for o in e["options"]} for family, _, e in entries if family == "lifeChoice"}
    stage_ids = set()
    for stage in manifest["lifeChoiceStages"]:
        fields(stage, ["id", "firstWeek", "lastWeek"], ["id", "firstWeek", "lastWeek"], "stage")
        number(stage["firstWeek"], 1, 51, "stage", integer=True)
        number(stage["lastWeek"], stage["firstWeek"], 51, "stage", integer=True)
        require(stage["id"] not in stage_ids, "stage", "duplicate stage ID")
        stage_ids.add(stage["id"])
    used_text = set()

    def text_keys(entry, where):
        for key, value in entry.items():
            if key in ["titleKey", "messageKey", "storyKey", "resultKey", "photoTitleKey"]:
                require(value in strings and isinstance(strings[value], str) and strings[value], where, f"missing text: {value}")
                used_text.add(value)

    celebrity_ids = set()
    for filename in manifest.get("celebrityFiles", []):
        for person in load(content_path(filename)):
            fields(person, ["id", "titleKey"], ["id", "titleKey"], filename)
            require(isinstance(person["id"], str) and person["id"] and person["id"] not in celebrity_ids, filename, "invalid or duplicate celebrity ID")
            celebrity_ids.add(person["id"])
            text_keys(person, filename)

    for family, filename, event in entries:
        where = f"{filename} [{event['id']}]"
        text_keys(event, where)
        if "condition" in event:
            condition(event["condition"], where, world_ids, choices, district_ids)
        if family == "celebrityActingEvent":
            required = ["id", "sourceNPCID", "districtID", "condition", "oncePerJourney", "requiresTimeForBonus", "delayTurns", "bonusMultiplier", "invitation", "premiere", "options"]
            fields(event, required, required, where)
            require(event["sourceNPCID"] in celebrity_ids, where, "unknown celebrity ID")
            require(event["districtID"] in district_ids, where, "unknown acting-event district")
            for key in ["oncePerJourney", "requiresTimeForBonus"]:
                require(type(event[key]) is bool, where, f"{key} must be boolean")
            number(event["delayTurns"], 1, 51, where, integer=True)
            number(event["bonusMultiplier"], 1, 100, where, integer=True)
            for key in ["invitation", "premiere"]:
                fields(event[key], ["titleKey", "messageKey"], ["titleKey", "messageKey"], where)
                text_keys(event[key], where)
            options = event["options"]
            require(isinstance(options, list) and 1 <= len(options) <= 8, where, "invalid acting options")
            option_ids = set()
            for option in options:
                required_option = ["id", "titleKey", "resultKey", "fee", "healthDelta", "luckDelta"]
                fields(option, required_option, required_option, where)
                require(isinstance(option["id"], str) and option["id"] and option["id"] not in option_ids, where, "invalid or duplicate acting option")
                option_ids.add(option["id"])
                text_keys(option, where)
                number(option["fee"], 0, 1000000, where, integer=True)
                for key in ["healthDelta", "luckDelta"]:
                    number(option[key], -100, 100, where, integer=True)
        elif family == "celebrityPhotoEvent":
            required = ["id", "sourceNPCID", "districtID", "condition", "invitation", "selection", "declined", "options"]
            fields(event, required, required, where)
            require(event["sourceNPCID"] in celebrity_ids, where, "unknown celebrity ID")
            require(event["districtID"] in district_ids, where, "unknown photo-event district")
            for key in ["invitation", "selection", "declined"]:
                fields(event[key], ["titleKey", "messageKey"], ["titleKey", "messageKey"], where)
                text_keys(event[key], where)
            options = event["options"]
            require(isinstance(options, list) and 1 <= len(options) <= 8, where, "invalid photo options")
            option_ids = set()
            for option in options:
                required_option = ["id", "titleKey", "resultKey", "photoTitleKey", "salePrice", "buff"]
                fields(option, required_option, required_option, where)
                require(isinstance(option["id"], str) and option["id"] and option["id"] not in option_ids, where, "invalid or duplicate photo option")
                option_ids.add(option["id"])
                text_keys(option, where)
                number(option["salePrice"], 1, 1000000, where, integer=True)
                buff = option["buff"]
                buff_fields = ["id", "titleKey", "messageKey", "durationTurns", "luckDelta", "healthPerTurn", "workIncomeMultiplier"]
                fields(buff, buff_fields, buff_fields, where)
                require(isinstance(buff["id"], str) and buff["id"], where, "empty buff ID")
                text_keys(buff, where)
                number(buff["durationTurns"], 1, 52, where, integer=True)
                number(buff["luckDelta"], -100, 100, where, integer=True)
                number(buff["healthPerTurn"], -100, 100, where, integer=True)
                number(buff["workIncomeMultiplier"], 0, 3, where)
        elif family == "investmentEvent":
            story_fields = ["invitation", "accepted", "declined", "profit", "loss"]
            required = ["id", "sourceNPCID", "districtID", "encounterChance", "minimumInvestment", "delayTurns", "profitChance", "profitPercent", "lossPercent"] + story_fields
            fields(event, required + ["condition"], required, where)
            require(isinstance(event["sourceNPCID"], str) and event["sourceNPCID"], where, "invalid NPC source ID")
            if "celebrityFiles" in manifest:
                require(event["sourceNPCID"] in celebrity_ids, where, "unknown celebrity ID")
            require(event["districtID"] in district_ids, where, "unknown invitation district")
            for key in ["encounterChance", "profitChance"]:
                number(event[key], 0, 1, where)
            for key, upper in [("minimumInvestment", 1000000000), ("delayTurns", 51), ("profitPercent", 1000), ("lossPercent", 100)]:
                number(event[key], 1, upper, where, integer=True)
            for key in story_fields:
                fields(event[key], ["titleKey", "messageKey"], ["titleKey", "messageKey"], where)
                text_keys(event[key], where)
        elif family == "world":
            fields(event, ["id", "titleKey", "messageKey", "imageName", "durationWeeks", "modifiers", "selection", "condition"], ["id", "titleKey", "messageKey", "imageName", "durationWeeks", "modifiers", "selection"], where)
            weight(event["selection"], where)
            number(event["durationWeeks"], 1, 52, where, integer=True)
            modifier_keys = ["workIncome", "tradeIncome", "bankInterest", "investmentReturn", "debtInterest", "healthChange", "marketPrice"]
            fields(event["modifiers"], modifier_keys + ["investmentReturnCap"], modifier_keys, where)
            for key in modifier_keys:
                number(event["modifiers"][key], 0, 10, where)
            if "investmentReturnCap" in event["modifiers"]:
                number(event["modifiers"]["investmentReturnCap"], -100, 10000, where, integer=True)
        elif family == "lifeChoice":
            fields(event, ["id", "titleKey", "storyKey", "stage", "options", "imageName", "condition"], ["id", "titleKey", "storyKey", "stage", "options"], where)
            require(event["stage"] in stage_ids and event["options"], where, "invalid stage or empty options")
            require(len(choices[event["id"]]) == len(event["options"]), where, "duplicate option ID")
            for option in event["options"]:
                fields(option, ["id", "titleKey", "resultKey", "cashDelta", "healthDelta", "luckDelta"], ["id", "titleKey", "resultKey", "cashDelta", "healthDelta", "luckDelta"], where)
                require(isinstance(option["id"], str) and option["id"], where, "empty or invalid option ID")
                text_keys(option, where)
                for key in ("cashDelta", "healthDelta", "luckDelta"):
                    number(option[key], -1000000000, 1000000000, where, integer=True)
        else:
            fields(event, ["id", "kind", "group", "titleKey", "messageKey", "cashDelta", "healthDelta", "reputationDelta", "affectedCommodityID", "marketPriceMultiplier", "grantedQuantity", "districtIDs", "triggerChance", "workIncomeMultiplier", "baseCashDelta", "skippedWeeks", "encounterTone", "luckDelta", "condition", "selectionWeight", "effects"], ["id", "kind", "group", "titleKey", "messageKey", "cashDelta", "healthDelta", "reputationDelta"], where)
            require(event["group"] in ["market", "health", "money"], where, "invalid event group")
            require(event["kind"] in ["opportunity", "setback", "health", "reputation"], where, "invalid event kind")
            for key in ["cashDelta", "healthDelta", "reputationDelta", "luckDelta"]:
                if key in event:
                    number(event[key], -1000000000, 1000000000, where, integer=True)
            if "selectionWeight" in event:
                weight(event["selectionWeight"], where)
            for key in ["marketPriceMultiplier", "workIncomeMultiplier"]:
                if key in event:
                    number(event[key], 0, 10, where)
            if "triggerChance" in event:
                require(event["id"] == "figueroa-vice-sweep", where, "triggerChance is reserved for the existing Figueroa work hook; use selectionWeight for random location events")
                number(event["triggerChance"], 0, 1, where)
            if "grantedQuantity" in event:
                number(event["grantedQuantity"], 0, 1000000, where, integer=True)
            if "affectedCommodityID" in event:
                require(event["affectedCommodityID"] in commodity_ids, where, "unknown commodity ID")
            if "districtIDs" in event:
                require(isinstance(event["districtIDs"], list) and set(event["districtIDs"]) <= district_ids, where, "unknown district ID")
            if "effects" in event:
                require(isinstance(event["effects"], list) and len(event["effects"]) <= 64, where, "invalid effect list")
                require("encounterTone" in event, where, "explicit effects require an authored encounterTone")
                require(all(event.get(key, 0) == 0 for key in ["cashDelta", "healthDelta", "luckDelta", "reputationDelta"]), where, "explicit effects cannot duplicate legacy deltas")
                require(not any(key in event for key in ["affectedCommodityID", "marketPriceMultiplier", "grantedQuantity"]), where, "explicit effects cannot duplicate legacy commodity changes")
                require(not any(key in event for key in ["workIncomeMultiplier", "baseCashDelta", "skippedWeeks"]), where, "explicit effects cannot use work or skipped-week metadata")
                for effect in event["effects"]:
                    require(isinstance(effect, dict) and len(effect) == 1, where, "effect needs one tagged case")
                    kind, values = next(iter(effect.items()))
                    if kind in ["cash", "health", "luck"]:
                        fields(values, ["amount"], ["amount"], where)
                        number(values["amount"], -1000000000, 1000000000, where, integer=True)
                    elif kind in ["marketPrice", "grantCommodity"]:
                        value_key = "multiplier" if kind == "marketPrice" else "quantity"
                        fields(values, ["commodityID", value_key], ["commodityID", value_key], where)
                        require(values["commodityID"] in commodity_ids, where, "unknown effect commodity")
                        number(values[value_key], 0, 10 if kind == "marketPrice" else 1000000, where, integer=kind == "grantCommodity")
                    else:
                        raise ValueError(f"{where}: unknown effect case {kind}")
            if "encounterTone" in event:
                require(event["encounterTone"] in ["favorable", "unfavorable", "mixed"], where, "invalid encounter tone")
        image = event.get("imageName")
        if family == "location" and (event["group"] == "health" or event["id"] == "freeway-gridlock"):
            image = "Event_" + event["id"]
        if image and not args.data_only:
            image_set = root / "SurviveInLA/Resources/Assets.xcassets" / (image + ".imageset")
            require((image_set / "Contents.json").exists(), where, f"missing image: {image}")
            filenames = [item["filename"] for item in load(image_set / "Contents.json").get("images", []) if "filename" in item]
            require(filenames and all((image_set / name).is_file() for name in filenames), where, f"missing image file: {image}")

    if args.export_catalog:
        report = ["# 事件内容总表", "", "由 `python3 tools/content/validate.py --export-catalog` 生成，请修改 JSON 来源后重新生成。", "", f"内容版本：{manifest['contentVersion']}。世界事件从第 {schedule['firstWeek']} 周起，每 {schedule['intervalWeeks']} 周抽取；同一事件持续期间不重复。", "", "| ID | 类型 | 标题 | 地点/阶段 | 世界收益评级 | 来源 |", "|---|---|---|---|---|---|"]
        for family, filename, event in entries:
            rating = event.get("selection", {})
            detail = f"{rating.get('favorability', '')} / {rating.get('strength', '')}" if rating else "—"
            scope = event.get("districtID") or ", ".join(event.get("districtIDs", [])) or (str(event["stage"]) if "stage" in event else "全局")
            title_key = event["invitation"]["titleKey"] if family in ("investmentEvent", "celebrityPhotoEvent", "celebrityActingEvent") else event["titleKey"]
            report.append(f"| {event['id']} | {('名人交互·投资' if family == 'investmentEvent' else '名人交互·合影' if family == 'celebrityPhotoEvent' else '名人交互·片场' if family == 'celebrityActingEvent' else event.get('group', family))} | {strings[title_key]} | {scope} | {detail} | {filename} |")
        dest = root / "docs/generated/event-catalog.md"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text("\n".join(report) + "\n")
    print(f"Validated {len(entries)} events, {len(used_text)} text references; content {manifest['contentVersion']}.")
    if args.world_weights is not None:
        luck = min(100, max(0, args.world_weights))
        weighted = []
        for family, _, event in entries:
            if family != "world":
                continue
            rule = event["selection"]
            direction = {"favorable": 1, "mixed": 0, "unfavorable": -1}[rule["favorability"]]
            value = rule["baseWeight"] * schedule["luckScale"] ** (direction * rule["strength"] * (luck - 50) / 50)
            weighted.append((strings[event["titleKey"]], value))
        total = sum(value for _, value in weighted)
        print(f"Luck {luck}; assumes all events eligible and none already active:")
        for title, value in weighted:
            print(f"  {title}: weight={value:.4f}, share={(value / total if total else 0):.2%}")
    if args.data_only:
        print("Artwork checks skipped (--data-only); this is not a full asset validation.")
    unused = set(strings) - used_text
    if unused:
        print(f"Warning: {len(unused)} unused localisation keys")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"error: {error}") from error
