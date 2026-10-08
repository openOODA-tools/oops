Name:           oops
Version:        0.2.0
Release:        1%{?dist}
Summary:        Process tree visualizer and signal controller with systemd slice grouping
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oops
Source0:        oops-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oops is a sovereign process tree visualizer and signal controller written in pure
openOODA, featuring native systemd slice classification (system.slice, user.slice),
hierarchical process tree visualization, safe signal dispatch under ProcessCap, and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oops
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oops-uninstall

%files
/usr/bin/oops
/usr/bin/oops-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Elevate to S+ tier: streaming JSON-RPC 2.0 MCP stdio server, 4 tools, ASCII connectors, and tree/list CLI improvements

* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign release: systemd slice grouping, tree visualization, and MCP stdio surface
