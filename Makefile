.PHONY: app run run-debug stop test clean

app:
	./scripts/build-app.sh

run: app stop
	open build/OLEDGuard.app

# 動作確認用: 「1分」を6秒として扱う(5分設定なら30秒で待ち受けに入る)
run-debug: app stop
	open build/OLEDGuard.app --args --minute-seconds 6

# 起動中のものを終了させ、終わるまで待つ(すぐ open すると -600 エラーになるため)
stop:
	-@pkill -x OLEDGuard; while pgrep -x OLEDGuard >/dev/null; do sleep 0.2; done

test:
	swift run OLEDGuardCoreChecks

clean:
	rm -rf .build build
