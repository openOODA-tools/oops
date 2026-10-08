# oops v0.2.0 Makefile
#
# Build, verification gate, test suite, and tri-distribution packaging.
#
# Usage:
#   make build       - compile main.oo to dist/oops
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run end-to-end integration and MCP tests
#   make bench       - run performance benchmark suite
#   make package     - build deb, rpm, and arch packages
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oops

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= 0.2.0

.PHONY: build check line-cap file-law academy density verify clean test bench package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oops-linux-x86_64
	@sha256sum dist/oops-linux-x86_64 > dist/oops-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oops-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== Tier 1: Core CLI Flags, Tree View, Flat List, Slices, PID, ASCII, and Options ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@./$(BIN) -h > /dev/null && echo "PASS: -h"
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@./$(BIN) -v | grep -q "0.2.0" && echo "PASS: -v"
	@./$(BIN) --help | grep -q -- "-t, --tree" && echo "PASS: --help documents -t"
	@./$(BIN) --help | grep -q -- "-l, --list" && echo "PASS: --help documents -l"
	@./$(BIN) --help | grep -q -- "-s, --slice" && echo "PASS: --help documents -s"
	@./$(BIN) --help | grep -q -- "-p, --pid" && echo "PASS: --help documents -p"
	@./$(BIN) --help | grep -q -- "-k, --kill" && echo "PASS: --help documents -k"
	@./$(BIN) --help | grep -q -- "--ascii" && echo "PASS: --help documents --ascii"
	@./$(BIN) --help | grep -q -- "--no-color" && echo "PASS: --help documents --no-color"
	@./$(BIN) --help | grep -q -- "--mcp" && echo "PASS: --help documents --mcp"
	@OODA_NO_JAIL=1 ./$(BIN) | grep -q "systemd" && echo "PASS: default process tree"
	@OODA_NO_JAIL=1 ./$(BIN) -t | grep -q "systemd" && echo "PASS: explicit tree flag -t"
	@OODA_NO_JAIL=1 ./$(BIN) -l | grep -q "systemd" && echo "PASS: flat list flag -l"
	@OODA_NO_JAIL=1 ./$(BIN) --flat | grep -q "systemd" && echo "PASS: flat list alias --flat"
	@OODA_NO_JAIL=1 ./$(BIN) --list | grep -q "systemd" && echo "PASS: flat list alias --list"
	@OODA_NO_JAIL=1 ./$(BIN) -s system | grep -q "system" && echo "PASS: slice filter -s system"
	@OODA_NO_JAIL=1 ./$(BIN) --slice=system | grep -q "system" && echo "PASS: long slice flag --slice=system"
	@OODA_NO_JAIL=1 ./$(BIN) -ssystem | grep -q "system" && echo "PASS: attached short slice flag -ssystem"
	@OODA_NO_JAIL=1 ./$(BIN) -p 1 | grep -q "systemd" && echo "PASS: pid filter -p 1"
	@OODA_NO_JAIL=1 ./$(BIN) --pid=1 | grep -q "systemd" && echo "PASS: long pid flag --pid=1"
	@OODA_NO_JAIL=1 ./$(BIN) -p1 | grep -q "systemd" && echo "PASS: attached short pid flag -p1"
	@OODA_NO_JAIL=1 ./$(BIN) --ascii | grep -E -q '(\\|\|)-- ' && echo "PASS: --ascii emits ASCII branch connectors"
	@OODA_NO_JAIL=1 ./$(BIN) | grep -E -q '(├──|└──)' && echo "PASS: default tree emits Unicode connectors"
	@OODA_NO_JAIL=1 ./$(BIN) systemd | grep -q "systemd" && echo "PASS: positional filter systemd"
	@! ./$(BIN) -k TERM > /dev/null 2>&1 && echo "PASS: -k without -p exits error"
	@! ./$(BIN) -k INVALID -p 1 > /dev/null 2>&1 && echo "PASS: -k with invalid signal exits error"
	@sh -c 'sh -c "sh -c \"sh -c \\\"sleep 1; :\\\" ; :\" ; :"' & P=$$!; sleep 0.1; OODA_NO_JAIL=1 ./$(BIN) -p $$P | grep -q "sleep" && echo "PASS: deep tree hierarchy (>4 levels) rendered"; kill -9 $$P 2>/dev/null || true
	@ESC=$$(printf '\033'); ! (OODA_NO_JAIL=1 ./$(BIN) --no-color | grep -q "$$ESC") && echo "PASS: --no-color suppresses ANSI escapes"
	@OODA_NO_JAIL=1 ./$(BIN) -theme classic/1982 | grep -q "systemd" && echo "PASS: -theme override"
	@echo "=== Tier 2: MCP Handshake & Protocol Framing ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "2024-11-05" && echo "PASS: MCP initialize protocolVersion"
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q '"name":"oops","version":"0.2.0"' && echo "PASS: MCP initialize serverInfo"
	@printf '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP ping"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "process_tree" && echo "PASS: MCP tools/list process_tree"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "find_process" && echo "PASS: MCP tools/list find_process"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "process_details" && echo "PASS: MCP tools/list process_details"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "send_signal" && echo "PASS: MCP tools/list send_signal"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP notifications/initialized produces no response"
	@printf '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":null' && echo "PASS: MCP shutdown"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"exit","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP exit terminates cleanly"
	@test "$$(printf '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -c '"result":{}')" = "2" && echo "PASS: MCP concatenated JSON-RPC messages without newline"
	@printf '{"jsonrpc":"2.0","id":99,"method":"ping","params":{}}' | ./$(BIN) --mcp | grep -q '"id":99' && echo "PASS: MCP request without trailing newline"
	@(sleep 0.1 && printf '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}\n') | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP stdio idle pause does not crash server"
	@echo "=== Tier 3: All 4 MCP Tools & Execution Edge Cases ==="
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"process_tree","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "systemd" && echo "PASS: MCP process_tree default tree"
	@printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"process_tree","arguments":{"format":"table"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "PID" && echo "PASS: MCP process_tree format table"
	@printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"process_tree","arguments":{"format":"json"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "rss_kb" && echo "PASS: MCP process_tree format json"
	@printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"process_tree","arguments":{"slice":"system","format":"table"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "system" && echo "PASS: MCP process_tree slice filter"
	@printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"find_process","arguments":{"name":"systemd"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "systemd" && echo "PASS: MCP find_process matching systemd"
	@printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"find_process","arguments":{"name":"systemd"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "rss_kb" && echo "PASS: MCP find_process rss_kb field"
	@printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"find_process","arguments":{"name":"__nonexistent_proc_xyz__"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q '\[\\n\]' && echo "PASS: MCP find_process empty matches returns empty array"
	@printf '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "systemd" && echo "PASS: MCP process_details comm systemd"
	@printf '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "cmdline" && echo "PASS: MCP process_details cmdline"
	@printf '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "cgroup_path" && echo "PASS: MCP process_details cgroup_path"
	@printf '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "rss_kb" && echo "PASS: MCP process_details rss_kb"
	@printf '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "threads" && echo "PASS: MCP process_details threads"
	@printf '{"jsonrpc":"2.0","id":22,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":99999999,"signal":"TERM"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP send_signal dispatches to target PID (safely fails on non-existent)"
	@printf '{"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":"1"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "systemd" && echo "PASS: MCP process_details string pid"
	@printf '{"jsonrpc":"2.0","id":24,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":99999999,"signal":15}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP send_signal accepts integer signal 15"
	@printf '{"jsonrpc":"2.0","id":25,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":99999999,"signal":"term"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP send_signal accepts lowercase signal name"
	@echo "=== Tier 4: Negative Trust & Error Responses ==="
	@printf 'invalid json string\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid json exits -32600"
	@printf '{"jsonrpc":"1.0","id":30,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid jsonrpc version exits -32600"
	@printf '{"jsonrpc":"2.0","id":31,"method":"","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP empty method exits -32600"
	@printf '{"jsonrpc":"2.0","id":32,"method":"nonexistent_method","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown method exits -32601"
	@printf '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown tool exits -32601"
	@printf '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP missing tool name exits -32602"
	@printf '{"jsonrpc":"2.0","id":35,"method":"tools/call","params":{"name":"process_tree","arguments":{"format":"invalid_fmt"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_tree invalid format exits -32602"
	@printf '{"jsonrpc":"2.0","id":36,"method":"tools/call","params":{"name":"process_tree","arguments":{"format":123}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_tree numeric format exits -32602"
	@printf '{"jsonrpc":"2.0","id":37,"method":"tools/call","params":{"name":"find_process","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP find_process missing name exits -32602"
	@printf '{"jsonrpc":"2.0","id":38,"method":"tools/call","params":{"name":"find_process","arguments":{"name":123}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP find_process numeric name exits -32602"
	@printf '{"jsonrpc":"2.0","id":39,"method":"tools/call","params":{"name":"process_details","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_details missing pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":-1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_details negative pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":41,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":0}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_details pid 0 exits -32602"
	@printf '{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":99999999}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP process_details nonexistent pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":43,"method":"tools/call","params":{"name":"send_signal","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal missing pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":44,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":-1,"signal":"TERM"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal negative pid rejection exits -32602"
	@printf '{"jsonrpc":"2.0","id":45,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":0,"signal":"TERM"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal pid 0 rejection exits -32602"
	@printf '{"jsonrpc":"2.0","id":46,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":"0","signal":"TERM"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal string pid 0 rejection exits -32602"
	@printf '{"jsonrpc":"2.0","id":47,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":"-1","signal":"TERM"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal string negative pid rejection exits -32602"
	@printf '{"jsonrpc":"2.0","id":48,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal missing signal exits -32602"
	@printf '{"jsonrpc":"2.0","id":49,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":1,"signal":"INVALID_SIG"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal invalid signal exits -32602"
	@printf '{"jsonrpc":"2.0","id":50,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":1,"signal":0}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal signal 0 exits -32602"
	@printf '{"jsonrpc":"2.0","id":51,"method":"tools/call","params":{"name":"send_signal","arguments":{"pid":1,"signal":999}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP send_signal signal 999 exits -32602"
	@echo "=== Double-Run Determinism & Response Consistency ==="
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism tools/list Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":7,"method":"ping","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":7,"method":"ping","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism ping Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -o 'systemd')"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -o 'systemd')"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism process_details PID 1 comm Run_1 == Run_2"
	@echo "=== Packaging & Installer Smoke Tests ==="
	@./install.sh --dry-run > /dev/null && echo "PASS: install.sh --dry-run"
	@./install.sh --uninstall --dry-run > /dev/null && echo "PASS: install.sh --uninstall --dry-run"
	@./uninstall.sh --dry-run > /dev/null && echo "PASS: uninstall.sh --dry-run"
	@echo "ALL TESTS PASSED"

bench: $(BIN)
	@echo "=== Running oops performance benchmarks ==="
	@echo "--- CLI tree rendering benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 30); do OODA_NO_JAIL=1 ./$(BIN) > /dev/null; done'
	@echo "--- CLI flat listing benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 30); do OODA_NO_JAIL=1 ./$(BIN) -l > /dev/null; done'
	@echo "--- MCP process_tree benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 30); do printf '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"process_tree","arguments":{"format":"json"}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP find_process benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 50); do printf '\''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"find_process","arguments":{"name":"systemd"}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP process_details benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 50); do printf '\''{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"process_details","arguments":{"pid":1}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null; done'
	@echo "Benchmark complete."

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oops
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oops-uninstall
	@echo "installed oops and oops-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oops $(DESTDIR)$(BINDIR)/oops-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oops $(HOME)/.config/oops; echo "purged user cache and config"; fi
	@echo "uninstalled oops and oops-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oops
	@chmod 0755 dist/deb-root/usr/bin/oops
	@cp uninstall.sh dist/deb-root/usr/bin/oops-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oops-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oops_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oops_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oops-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oops.spec > ~/rpmbuild/SPECS/oops.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oops.spec
	@cp ~/rpmbuild/RPMS/x86_64/oops-$(VERSION)*.rpm dist/ 2>/dev/null || true
	@if ls dist/oops-$(VERSION)-1.*.x86_64.rpm 1> /dev/null 2>&1; then cp dist/oops-$(VERSION)-1.*.x86_64.rpm dist/oops-$(VERSION)-1.x86_64.rpm; fi
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oops
	@chmod 0755 dist/arch-pkg/usr/bin/oops
	@cp uninstall.sh dist/arch-pkg/usr/bin/oops-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oops-uninstall
	@printf "pkgname = oops\npkgbase = oops\npkgver = $(VERSION)-1\npkgdesc = Process tree visualizer and signal controller with systemd slice grouping and MCP surface\nurl = https://github.com/openOODA-tools/oops\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oops\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oops-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD dist/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oops-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cp $(BIN) dist/oops-linux-x86_64
	@chmod 0755 dist/oops-linux-x86_64
	@(cd dist && sha256sum oops-linux-x86_64 > oops-linux-x86_64.sha256)
	@(cd dist && sha256sum oops* > checksums.txt)
	@echo "built all packages and generated dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
