VERSION = 0.0.9

_default:
	@echo "Nothing to make. Try make dist"

clean:
	rm -fr osg-ca-scripts-*

dist:
	mkdir -p osg-ca-scripts-$(VERSION)
	cp -pr bin/ etc/ libexec/ lib/ sbin/ init.d/ cron.d/ logrotate/ osg-ca-scripts-$(VERSION)/
	tar zcf osg-ca-scripts-$(VERSION).tar.gz `find osg-ca-scripts-$(VERSION) ! -name *~ ! -name .#* ! -type d | grep -v '\.svn'`
	rm -fr osg-ca-scripts-$(VERSION)
