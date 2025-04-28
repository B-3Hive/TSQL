SELECT olm.[name], olm.[file_version], olm.[product_version], olm.[description], ova.[region_size_in_bytes], olm.[base_address], ova.[region_base_address], ova.[region_type]

FROM sys.dm_os_virtual_address_dump ova 

INNER JOIN sys.dm_os_loaded_modules olm ON olm.base_address = ova.region_allocation_base_address

ORDER BY name


--To find the cumulative VAS size per modules, then run this query:

SELECT olm.[name], olm.[file_version], olm.[product_version], olm.[description], SUM(ova.[region_size_in_bytes])/1024 [Module Size in KB], olm.[base_address]

FROM sys.dm_os_virtual_address_dump ova 

INNER JOIN sys.dm_os_loaded_modules olm ON olm.base_address = ova.region_allocation_base_address

GROUP BY olm.[name],olm.[file_version], olm.[product_version], olm.[description],olm.[base_address]

ORDER BY [Module Size in KB] DESC 

--Here is the query to get the total virtual address space allocated to load the code --of modules inside SQL Server address space:

SELECT SUM(ova.[region_size_in_bytes])/1024.0/1024.0 [Total Module Size in MB]

FROM sys.dm_os_virtual_address_dump ova 

INNER JOIN sys.dm_os_loaded_modules olm ON olm.base_address = ova.region_allocation_base_address
