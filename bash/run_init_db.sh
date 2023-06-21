#!/bin/bash
#1
docker pull postgres
#2
docker run --name DEDB -p 5432:5432 -e POSTGRES_USER=test_sde -e POSTGRES_PASSWORD=@sde_password012 -e POSTGRES_DB=demo -d postgres
#3
sleep 5
#4
docker ps
#5
docker exec DEDB pg-isready
#6
docker exec postgres-container psql -U test_sde -d demo -c "SELECT * FROM pg_database"
#7
docker cp $HOME/sde_test_db/sql/init_db/demo.sql DEDB://var/lib/postgresql/data/
#8
docker exec DEDB psql -U test_sde -d demo -f //var/lib/postgresql/data/demo.sql