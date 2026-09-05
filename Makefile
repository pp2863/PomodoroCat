APP_NAME = PomodoroCat

.PHONY: build run debug clean

build:
	./Scripts/build_app.sh release

run: build
	open $(APP_NAME).app

debug:
	swift build
	.build/debug/$(APP_NAME)

clean:
	rm -rf .build $(APP_NAME).app
