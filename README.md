<div align="center">

# im_text_field

<sub>A lightweight TextField enhancement adding real‑time trigger detection (@ # / ...), streaming keyword callbacks, and inline rich embedding via WidgetSpan placeholders.</sub>
</div>

## ✨ Features

- Multiple trigger characters: Any characters (e.g. `@`, `#`, `/`) each with an independent callback and rendering builder.
- Real‑time keyword streaming: After a trigger starts a match before the caret, the current keyword (excluding the trigger symbol) is continuously emitted so you can show/update an external suggestion panel.
- Arbitrary widget embedding: Insert fully custom `WidgetSpan`s (images, animated emoji, tags, etc.).
- High compatibility: Wraps and forwards native `TextField` parameters; no enforced UI shape (no built‑in Overlay layer).

## 🚀 Quick Start

### 1. Add dependency

Add to `pubspec.yaml`:

```yaml
dependencies:
  im_text_field: latest
```

### 2. Create controller & trigger configuration

```dart
final mentionController = ImEditingController({
  '@': ImTrigger(
    onTrigger: (keyword) {
      // Fetch candidate users based on keyword and show overlay
      mentionOverlay.show(keyword);
    },
    builder: ({required context, required data, style, required withComposing}) {
      final user = data as User;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 9, backgroundImage: NetworkImage(user.avatar)),
        const SizedBox(width: 4),
        Text('@${user.name}', style: style?.copyWith(color: Colors.blue)),
      ]);
    },
  ),
});
```

### 3. Use `ImTextField`

```dart
ImTextField(
  controller: mentionController,
  onFinishMatching: () => hideAllOverlays(),
  maxMatchLength: 50,
);
```

### 4. Insert a selected result

```dart
void onUserSelected(User user) {
  mentionController.insertTriggeredValue('@', user);
  hideMentionOverlay();
}
```

### 5. Insert any `WidgetSpan`

```dart
mentionController.insertWidgetSpan(
  {'type': 'emoji', 'value': '🔥'},
  const WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Text('🔥', style: TextStyle(fontSize: 18)),
  ),
);
```

## ❓ FAQ

Q: When is `onTrigger` fired?

A: When you input a trigger character and the character immediately before it is whitespace or not an English letter.
