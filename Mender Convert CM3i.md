# Mender Convert CM3i Project Progress

## Project Timeline

### **October 8, 2024 - First Test Image**
- Initial test image created for Radxa CM3i

### **October 13, 2024 - Hardware Arrival**
- Radxa CM3i board arrived (in afternoon delivery)

### **October 17, 2024 - Board Integration**
- Started with board interaction with board

### **October 18, 2024 - U-Boot Rebuild**
- Started from scratch rebuilding U-Boot
- Discovered and integrated Radxa toolset
- Began addressing boot sequence issues

### **October 20, 2024 - Boot Issues Resolved**
- Sorted U-Boot initramfs boot problems
- Resolved ext4 filesystem issues
- Stabilized boot process
- fw_env.config issues fixed

### **October 22, 2024 - Solution**
- Key deliverable
- Achieved fully working and verified Mender convert on stock image
- Successful A/B partition switching
- U-Boot environment configuration completed
- **Status:** No suitable Seergrills images available to work on yet
- Documentation for that provided in way of scripts 01-tenantsetup, 02-builddocker, 04-cm3grill, 04-cm3stock (03 is using 
docker), https://github.com/mendersoftware/mender-convert/blob/master/README.md https://docs.mender.io/operating-system-updates-debian-family/convert-a-mender-debian-image
- Code provided in the perfect modified mender convert