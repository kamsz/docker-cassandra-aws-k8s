#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
# or there are no args
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
	set -- cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
	chown -R cassandra /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONFIG"
	exec gosu cassandra "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	: ${CASSANDRA_LISTEN_ADDRESS='auto'}
	if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
		CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address)"
	fi

	: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

	if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
		CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address)"
	fi
	: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

	if [ -n "${CASSANDRA_NAME:+1}" ]; then
		: ${CASSANDRA_SEEDS:="cassandra"}
	fi
	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

  if [ -n "$CASSANDRA_CONFIG_TEMPLATE_DIR" ]; then
    cp $CASSANDRA_CONFIG_TEMPLATE_DIR/cassandra.yaml $CASSANDRA_CONFIG/cassandra.yaml
  fi

  if [ -n "$CASSANDRA_JVM_TEMPLATE_DIR" ]; then
    cp $CASSANDRA_JVM_TEMPLATE_DIR/jvm.options $CASSANDRA_CONFIG/jvm.options
  fi

	if [ -f "$CASSANDRA_CONFIG_TEMPLATE_DIR/$HOSTNAME.tokens" ]; then
		sed -i "s/# initial_token:/initial_token: $(cat $CASSANDRA_CONFIG_TEMPLATE_DIR/$HOSTNAME.tokens)/" "$CASSANDRA_CONFIG/cassandra.yaml"
	fi

	sed -ri 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml"

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml"
		fi
	done

  CASSANDRA_RACK=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
		fi
	done

  if [ -n "$CASSANDRA_DC_SUFFIX" ]; then
		sed -ri "s/^#dc_suffix=.*/dc_suffix=$CASSANDRA_DC_SUFFIX/g" cassandra-rackdc.properties
  fi
fi

exec "$@"
