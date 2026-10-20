.PHONY: app run test clean

app:
	./scripts/build-app.sh

# 起動中のものを終了してから起動し直す
run: app
	-pkill -x OLEDGuard
	open build/OLEDGuard.app

test:
	swift test

clean:
	rm -rf .build build
