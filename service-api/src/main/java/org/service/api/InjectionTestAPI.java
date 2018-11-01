package org.service.api;

import org.apache.nifi.dbcp.DBCPService;

public interface InjectionTestAPI extends DBCPService {
	public String test();

}
