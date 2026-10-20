.PHONY: app run run-debug test clean

app:
	./scripts/build-app.sh

# 起動中のものを終了してから起動し直す
run: app
	-pkill -x OLEDGuard
	open build/OLEDGuard.app

# 動作確認用: 「1分」を6秒として扱う(5分設定なら30秒で待ち受けに入る)
run-debug: app
	-pkill -x OLEDGuard
	open build/OLEDGuard.app --args --minute-seconds 6

test:
	swift test

clean:
	rm -rf .build build
