.PHONY: app dmg clean run

# Build the .app bundle
app:
	./scripts/build-app.sh

# Build the .dmg installer (builds app first)
dmg: app
	./scripts/build-dmg.sh

# Run the app directly
run: app
	open build/MeetsRecord.app

# Clean build artifacts
clean:
	rm -rf build/ .build/
