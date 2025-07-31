# Linkding Bookmark Service - User Setup Guide

## Overview

This guide helps you set up and use the Linkding bookmark service deployed on your Proxmox homelab. Linkding provides a self-hosted, web-based bookmark management solution that bypasses Work Mac IT restrictions and cloud storage limitations.

## Quick Access

**Service URL**: http://192.168.2.100:9090
**Default Login**: admin / changeme123

## Initial Setup

### 1. First Login and Password Change

1. Open your browser and navigate to: http://192.168.2.100:9090
2. Login with default credentials: `admin` / `changeme123`
3. **IMPORTANT**: Change your password immediately:
   - Click your username (top right) → Settings
   - Go to "Change Password" section
   - Set a secure password and save

### 2. Basic Configuration

#### Account Settings
- **Username**: Keep as `admin` or change if desired
- **Email**: Optional, for password recovery
- **Theme**: Choose Light or Dark theme
- **Bookmarks per page**: Set your preferred number (default: 20)

#### Privacy Settings
- **Make bookmarks public**: Keep DISABLED for private use
- **Enable bookmark sharing**: Optional, for sharing specific bookmarks
- **Enable public bookmark archive**: Keep DISABLED

### 3. Browser Extension Setup

Browser extensions provide the fastest way to add and search bookmarks.

#### Firefox Extension
1. Install: https://addons.mozilla.org/firefox/addon/linkding-extension/
2. Click the Linkding icon in your toolbar
3. Configure extension:
   - **Linkding URL**: `http://192.168.2.100:9090`
   - **API Token**: (Generate in next step)

#### Chrome Extension
1. Install: https://chrome.google.com/webstore/detail/linkding-extension/
2. Click the Linkding icon in your toolbar
3. Configure extension:
   - **Linkding URL**: `http://192.168.2.100:9090`
   - **API Token**: (Generate in next step)

#### Generate API Token
1. In Linkding web interface: Settings → Integrations
2. Click "Generate Token"
3. Copy the token and paste it into your browser extension settings
4. Test the connection (extension should show "Connected")

### 4. Import Existing Bookmarks

#### From Chrome
1. Chrome → Bookmarks → Bookmark Manager
2. Three dots menu → Export bookmarks
3. Save as HTML file
4. In Linkding: Settings → Import
5. Upload the HTML file
6. Review and confirm import

#### From Firefox
1. Firefox → Bookmarks → Show All Bookmarks
2. Import and Backup → Export Bookmarks to HTML
3. Save as HTML file
4. Follow same import process in Linkding

#### From Other Browsers
Most browsers support HTML bookmark export. Follow similar process.

## Daily Usage

### Adding Bookmarks

#### Via Browser Extension (Recommended)
1. Navigate to page you want to bookmark
2. Click Linkding extension icon
3. Add title, description, and tags
4. Click "Save"

#### Via Web Interface
1. Click "Add Bookmark" button
2. Enter URL, title, description
3. Add tags for organization
4. Choose to archive (save full page content)
5. Click "Save"

### Searching Bookmarks

#### Quick Search
- Use search box on main page
- Search by title, description, tags, or URL
- Results update as you type

#### Advanced Filtering
- **Tags**: Click tag labels to filter by specific tags
- **Unread**: Filter bookmarks marked as unread
- **Archived**: Show only bookmarks with archived content
- **Date Range**: Filter by creation or modification date

### Organizing Bookmarks

#### Tagging Strategy
- Use consistent tags: `work`, `personal`, `reference`, `tools`
- Combine tags: `work development`, `personal finance`
- Use hierarchical tags: `coding/javascript`, `coding/python`

#### Bulk Operations
- Select multiple bookmarks with checkboxes
- Apply tags to multiple bookmarks at once
- Delete multiple bookmarks
- Export selected bookmarks

### Reading Bookmarks

#### Archive Feature
- Toggle "Archive" when adding bookmarks
- Linkding saves full page content for offline reading
- Useful for articles that might disappear
- Access via "Archived" filter

#### Notes and Descriptions
- Add personal notes when bookmarking
- Useful for remembering why you saved the bookmark
- Searchable content for better discovery

## Advanced Features

### API Access

Generate API token for programmatic access:
- Settings → Integrations → Generate Token
- API Documentation: http://192.168.2.100:9090/api/
- Use for custom scripts or automation

### Backup Your Bookmarks

#### Manual Export
1. Settings → Export
2. Choose format (HTML, JSON, or CSV)
3. Download file for backup

#### Automated Backup (via Homelab Management)
```bash
# Create backup of all bookmark data
./homelab-unified.sh linkding backup

# Backups stored on Proxmox host at:
# /var/lib/linkding-backup-YYYYMMDD-HHMMSS/
```

### Multiple Devices

#### Access from Any Device
- Same URL works on mobile: http://192.168.2.100:9090
- Responsive web interface adapts to screen size
- All features available on mobile

#### Sync Between Devices
- No automatic sync (by design for privacy)
- Manual export/import between devices if needed
- API can be used for custom sync solutions

## Troubleshooting

### Cannot Access Service
1. Verify Proxmox host is running: `ping 192.168.2.100`
2. Check service status: `./homelab-unified.sh linkding status`
3. Check logs: `./homelab-unified.sh linkding logs`

### Browser Extension Not Working
1. Verify API token is correct
2. Check Linkding URL in extension settings
3. Ensure service is accessible from your network
4. Try regenerating API token

### Import Issues
1. Ensure HTML file is valid bookmark export
2. Check file size (very large files may timeout)
3. Try importing in smaller chunks
4. Check logs for error messages

### Performance Issues
1. Large bookmark collections may load slowly
2. Use pagination settings to show fewer bookmarks per page
3. Consider archiving old or unused bookmarks

## Best Practices

### Security
- Use strong password (changed from default)
- Keep Linkding updated via homelab management
- Regular backups of bookmark data
- Don't share API tokens

### Organization
- Develop consistent tagging strategy
- Use descriptive titles and descriptions
- Regular cleanup of unused bookmarks
- Group related bookmarks with same tags

### Workflow Integration
- Install browser extensions on all devices
- Set up regular backup schedule
- Consider API integration for advanced workflows
- Document your tagging conventions

## Support and Updates

### Service Management
```bash
# Check service status
./homelab-unified.sh linkding status

# View recent logs
./homelab-unified.sh linkding logs

# Create backup
./homelab-unified.sh linkding backup

# Access information
./homelab-unified.sh linkding access
```

### Updates
Service updates are handled through homelab management:
```bash
# Update to latest version (creates backup first)
./scripts/management/infrastructure/linkding-manager.sh update
```

### Getting Help
1. Check service logs for error messages
2. Verify network connectivity to Proxmox host
3. Review this guide for configuration issues
4. Check Linkding documentation: https://github.com/sissbruecker/linkding

---

**🔖 Happy Bookmarking!**

Your self-hosted bookmark service provides independent, private bookmark management that works across all your devices without relying on cloud services or corporate IT policies.