/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Decodable, Inc.
 *
 * Licensed under the Apache Software License version 2.0, available at http://www.apache.org/licenses/LICENSE-2.0
 */
package co.decodable.demos.arrayagg;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.dataview.ListView;
import org.apache.flink.table.catalog.DataTypeFactory;
import org.apache.flink.table.functions.AggregateFunction;
import org.apache.flink.table.types.DataType;
import org.apache.flink.table.types.inference.InputTypeStrategies;
import org.apache.flink.table.types.inference.TypeInference;

public class ArrayAgg <T> extends AggregateFunction<T[], ArrayAccumulator<T>> {

	private static final long serialVersionUID = 6560271654419701770L;
	private DataType elementType;

	@Override
	public ArrayAccumulator<T> createAccumulator() {
		return new ArrayAccumulator<T>();
	}

	@SuppressWarnings("unchecked")
	@Override
	public T[] getValue(ArrayAccumulator<T> acc) {
	
		//TODO-1: remove the 'return null;' and 
		//        add this method's implementation according
		//        to the hands-on lab docs here ...
		return null;

	}

	//TODO-2: add the additional missing methods
	//        according to the hands-on lab docs here ...

}
