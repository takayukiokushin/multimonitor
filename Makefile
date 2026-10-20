.PHONY: app run run-debug stop test clean

app:
	./scripts/build-app.sh

# open コマンドは -600 エラーで起動に失敗したり引数が渡らなかったりするため、実行ファイルを直接起動する
BIN = build/OLEDGuard.app/Contents/MacOS/OLEDGuard

run: app stop
	nohup $(BIN) >/dev/null 2>&1 &

# 動作確認用: 「1分」を6秒として扱う(5分設定なら30秒で待ち受けに入る)
run-debug: app stop
	nohup $(BIN) --minute-seconds 6 >/dev/null 2>&1 &

# 起動中のものを終了させ、終わるまで待つ
stop:
	-@pkill -x OLEDGuard; while pgrep -x OLEDGuard >/dev/null; do sleep 0.2; done

test:
	swift run OLEDGuardCoreChecks

clean:
	rm -rf .build build
