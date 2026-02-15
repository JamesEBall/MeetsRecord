.PHONY: app dmg install run clean icons

# Build the .app bundle
app:
	./scripts/build-app.sh

# Build and install to /Applications
install:
	./scripts/build-app.sh --install

# Build the .dmg installer (builds app first)
dmg: app
	./scripts/build-dmg.sh

# Run the app directly
run: app
	open build/MeetsRecord.app

# Regenerate icons
icons:
	python3 scripts/generate-icons.py

# Clean build artifacts
clean:
	rm -rf build/ .build/
