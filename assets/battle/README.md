# Battle Portrait Overrides

Battle unit visuals are resolved in this order:

1. `data/unit_visuals.json` mapping for the unit id
2. built-in placeholder fallback from `scripts/battle/unit_token.gd`

## Supported fields

- `portrait_path`: main battle portrait path
- `icon_path`: small badge icon path
- `portrait_scale`: scale multiplier for the portrait node
- `x_offset`: horizontal portrait offset in pixels
- `y_offset`: vertical portrait offset in pixels

## Recommended workflow

1. Put your final portrait file anywhere under `assets/battle/`
2. Update `data/unit_visuals.json`
3. Set `portrait_path` to the new `res://` asset path
4. Adjust `portrait_scale / x_offset / y_offset` until the unit sits correctly in the frame
5. Re-run the project

## Example

```json
{
  "hero_pilgrim_a01": {
    "portrait_path": "res://assets/battle/final/hero_pilgrim_a01.png",
    "icon_path": "res://assets/battle/icons/hero_pilgrim_a01.png",
    "portrait_scale": 0.92,
    "x_offset": 4,
    "y_offset": -8,
    "origin": "final"
  }
}
```

No battle UI code changes are required after that.
