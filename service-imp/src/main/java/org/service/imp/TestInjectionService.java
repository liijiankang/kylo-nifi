package org.service.imp;

import java.sql.Connection;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.apache.nifi.annotation.documentation.Tags;
import org.apache.nifi.components.PropertyDescriptor;
import org.apache.nifi.controller.AbstractControllerService;
import org.apache.nifi.controller.ControllerServiceInitializationContext;
import org.apache.nifi.dbcp.DBCPService;
import org.apache.nifi.processor.exception.ProcessException;
import org.apache.nifi.processor.util.StandardValidators;
import org.apache.nifi.reporting.InitializationException;
import org.service.api.InjectionTestAPI;

@Tags({"test","ljk"})
public class TestInjectionService extends AbstractControllerService implements InjectionTestAPI {

	public static final PropertyDescriptor User_Injection_Test = new PropertyDescriptor.Builder()
	        .name("User Injection Test")
	        .description("A database connection URL used to connect to a database. May contain database system name, host, port, database name and some parameters."
	            + " The exact syntax of a database connection URL is specified by your DBMS.")
	        .required(false)
	        .expressionLanguageSupported(true)
	        .addValidator(StandardValidators.NON_EMPTY_VALIDATOR)
	        .build();
	
	private static final List<PropertyDescriptor> properties;

    static {
        final List<PropertyDescriptor> props = new ArrayList<PropertyDescriptor>();
        props.add(User_Injection_Test);
        properties = Collections.unmodifiableList(props);
    }

	


	@Override
	protected List<PropertyDescriptor> getSupportedPropertyDescriptors() {
		return this.properties;
	}




	public Connection getConnection() throws ProcessException {
		return null;
	}




	public String test() {
		return null;
	}
}
