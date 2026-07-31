# Video acceptance

Treat these as separate gates:

1. **Request gate:** the user confirmed the exact input, prompt, duration, resolution, quota/cost uncertainty, and one-call action.
2. **Generation gate:** Grok returned one video path and made no second media call.
3. **Artifact gate:** the MP4 exists outside the transient session folder, has nonzero size, and `ffprobe` reports readable video metadata close to the requested duration and resolution class.
4. **Visual gate:** inspect the beginning, middle, and ending sample frames for subject identity, composition, geometry, unwanted text, duplication, deformation, and obvious continuity failures.
5. **Delivery gate:** provide the absolute local path and distinguish technical success from any creative defects.

For `480p` and `720p`, allow portrait or landscape orientation. Validate the requested resolution class against the shorter/longer edge as appropriate rather than assuming every source is 16:9.

If output is technically valid but visually weak, show the defects and propose a revised prompt. A revision is a new paid action and requires fresh confirmation.
