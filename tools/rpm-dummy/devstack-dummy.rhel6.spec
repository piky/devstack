Summary: Dummy packages that are replaced by pip
Name: devstack
Version: dummy
Release: 1
License: BSD
Group: System Environment/Base
Provides: python-setuptools, python-pip, python-crypto, python-lxml
Obsoletes: python-setuptools, python-pip, python-crypto, python-lxml

%description

This meta-package installs dummy dependencies which will be overridden
by pip locally during devstack install.

%files
%defattr(-,root,root,-)
%doc


%changelog
* Fri Jun 21 2013  <stack@rhel> - dummy-1
- Initial build.

