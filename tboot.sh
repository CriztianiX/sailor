#!/bin/bash
sudo luarocks make rockspecs/sailor-current-1.rockspec
git checkout test/dev-app/controllers/* test/dev-app/models/* test/dev-app/views/category/*

function run() {
	if [ -z "$1" ]; then
		echo "Should run in openresty or standalone?"
		exit 123
	fi

	export MODE=$1
	export TRAVIS=true
	export LUA=luajit 
	export SERVER=openresty 
	export DB_DRIVER=""
	export DB_USER=""
	export DB_NAME=""
	export DB_PASS=""

	######################################################################
	# Sqlite3
	######################################################################
	rm -rf test/sailor_test_lite3
	sqlite3 test/sailor_test_lite3 < test/dev-app/sql/sqlite3.sql
	export DB_DRIVER=sqlite3 
	export DB_USER="" 
	export DB_NAME=$(pwd)/test/sailor_test_lite3
	if [ "$MODE" = "resty" ]; then
		echo  "Running Sqlite3  with resty"
		( cd test/dev-app ; sailor test --resty )
	else
		echo  "Running Sqlite3 with standalone"
		( cd test/dev-app ; sailor test --verbose --coverage )
	fi

	######################################################################
	# MYSQL
	######################################################################
	mysql -u root -e 'DROP database sailor_test;'
	mysql -u root -e 'CREATE database sailor_test;'
	mysql -u root 'sailor_test' < test/dev-app/sql/mysql.sql
	export DB_DRIVER=mysql
	export DB_USER=root 
	export DB_NAME=sailor_test

	if [ "$MODE" = "resty" ]; then
		echo  "Running Mysql  with resty"
		( cd test/dev-app ; sailor test --resty )
	else
		echo  "Running Mysql with standalone"
		( cd test/dev-app ; sailor test --verbose --coverage )
	fi

	########################################################################
	# POSTGRES
	########################################################################
	sudo psql -c 'DROP database sailor_test;' -U pgsql
	sudo psql -c 'CREATE database sailor_test;' -U pgsql
	sudo psql -U pgsql 'sailor_test' < test/dev-app/sql/pgsql.sql 1>/dev/null 2>/dev/null
	export DB_DRIVER=postgres
	export DB_USER=pgsql
	export DB_NAME=sailor_test
	export DB_PASS="qwe123"
	if [ "$MODE" = "resty" ]; then
		echo  "Running Postgres  with resty"
		( cd test/dev-app ; sailor test --resty )
	else
		echo  "Running Postgres  with standalone"
		( cd test/dev-app ; sailor test --verbose --coverage )
	fi	
}


for mode in standalone resty
do
  run $mode
done