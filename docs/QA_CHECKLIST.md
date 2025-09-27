# MaintPulse QA Testing Checklist

## Pre-Release Testing Checklist

This comprehensive checklist ensures all features work correctly before production deployment.

---

## 🔧 Setup & Configuration

### Environment Setup
- [ ] **Environment variables** properly configured
  - [ ] SUPABASE_URL is valid and accessible
  - [ ] SUPABASE_ANON_KEY is working
  - [ ] All required variables present in .env
- [ ] **Database migrations** applied successfully
- [ ] **RLS policies** enabled and working correctly
- [ ] **Storage buckets** configured with proper policies
- [ ] **Seed data** loaded successfully

### Build & Deployment
- [ ] **Flutter build** completes without errors
- [ ] **Code formatting** passes (`flutter format`)
- [ ] **Static analysis** passes (`flutter analyze`)
- [ ] **Dependency vulnerabilities** check completed
- [ ] **Asset optimization** completed (images, icons)

---

## 🔐 Authentication & Authorization

### Sign Up Flow
- [ ] **Email validation** working correctly
- [ ] **Password requirements** enforced
- [ ] **Profile creation** saves tenant_id and role
- [ ] **Email verification** process (if implemented)
- [ ] **Error handling** for duplicate emails
- [ ] **Loading states** during sign up

### Sign In Flow
- [ ] **Valid credentials** allow access
- [ ] **Invalid credentials** show proper error
- [ ] **Remember me** functionality (if implemented)
- [ ] **Password reset** flow working
- [ ] **Session management** and auto-logout
- [ ] **Deep linking** after authentication

### Authorization
- [ ] **Admin users** can access all features
- [ ] **Requester users** have limited access
- [ ] **Tenant isolation** working (no cross-tenant data)
- [ ] **Route guards** prevent unauthorized access
- [ ] **API permissions** enforced on backend

---

## 🏢 Onboarding & Setup

### Company Setup
- [ ] **Company creation** saves correctly
- [ ] **Tenant ID generation** working
- [ ] **Company info validation** enforced
- [ ] **Navigation** to facility setup after completion
- [ ] **Back button** handling during onboarding
- [ ] **Form validation** messages clear

### Facility Setup
- [ ] **Facility creation** with proper tenant association
- [ ] **Multiple facilities** can be added
- [ ] **Facility validation** (name, address required)
- [ ] **Location services** integration (if implemented)
- [ ] **Photo upload** for facility (if implemented)
- [ ] **Navigation** to dashboard after completion

---

## 📋 Service Request Management

### Request Creation
- [ ] **Form validation** for required fields
- [ ] **Facility selection** working
- [ ] **Priority selection** affecting SLA
- [ ] **Description** accepts rich text/formatting
- [ ] **Attachment upload** (images, PDFs)
- [ ] **File size limits** enforced
- [ ] **SLA calculation** from contracts working

### Request List
- [ ] **Loading states** with skeleton UI
- [ ] **Pagination** loading more items
- [ ] **Search functionality** with debouncing
- [ ] **Filter options** (status, priority, facility)
- [ ] **Sort options** working correctly
- [ ] **Pull-to-refresh** updating data
- [ ] **Empty states** shown appropriately

### Request Detail
- [ ] **Status timeline** showing progression
- [ ] **SLA indicators** with color coding
- [ ] **Attachment gallery** with preview
- [ ] **Admin status transitions** working
- [ ] **Engineer assignment** (admin only)
- [ ] **Comments/notes** functionality
- [ ] **Real-time updates** reflecting changes

### Request Filters
- [ ] **Status filters** applied correctly
- [ ] **Facility filters** working
- [ ] **Priority filters** functional
- [ ] **Date range filters** (if implemented)
- [ ] **Clear filters** resets to default
- [ ] **Filter combinations** working together

---

## 📄 Contract Management

### Contract Creation
- [ ] **Contract type** selection (AMC/CMC)
- [ ] **Facility mapping** working
- [ ] **Terms and conditions** save correctly
- [ ] **Document upload** for contracts
- [ ] **Expiry date** validation
- [ ] **SLA terms** configuration

### Contract List & Detail
- [ ] **Contract listing** with pagination
- [ ] **Search functionality** working
- [ ] **Contract detail** view complete
- [ ] **Document preview/download** working
- [ ] **Facility assignments** displayed
- [ ] **Expiry notifications** working

---

## 🔧 Preventive Maintenance

### PM Schedule Generation
- [ ] **90-day schedule** generation working
- [ ] **Contract-based** PM visits created
- [ ] **Facility assignments** correct
- [ ] **Schedule conflicts** handling
- [ ] **Bulk generation** performance acceptable

### PM Visit Execution
- [ ] **Visit detail** page loads correctly
- [ ] **Checklist items** interactive
- [ ] **Photo capture** and upload working
- [ ] **Engineer signature** capture working
- [ ] **Visit completion** status updates
- [ ] **Notes and observations** save correctly

### PM Schedule Management
- [ ] **Upcoming visits** displayed correctly
- [ ] **Overdue visits** highlighted
- [ ] **Visit assignment** to engineers
- [ ] **Reschedule functionality** working
- [ ] **Visit history** accessible

---

## 💰 Billing & Payments

### Invoice Generation
- [ ] **Invoice creation** from completed requests
- [ ] **Line item calculation** accurate
- [ ] **Tax calculations** correct (18% GST)
- [ ] **Total rounding** to 2 decimal places
- [ ] **Customer information** populated
- [ ] **Invoice numbering** sequential

### Invoice Management
- [ ] **Invoice listing** with filters
- [ ] **Status transitions** (draft→sent→paid)
- [ ] **Admin-only operations** enforced
- [ ] **Search functionality** working
- [ ] **Invoice detail** view complete
- [ ] **PDF generation** (if implemented)

### PhonePe Payment Integration
- [ ] **Payment launcher** opening PhonePe app
- [ ] **UPI deeplink** working correctly
- [ ] **Fallback to UPI intent** working
- [ ] **Payment attempt** logging
- [ ] **Manual status updates** working
- [ ] **Reference ID** generation unique
- [ ] **Payment history** tracking

---

## 📊 Dashboard & Analytics

### Dashboard KPIs
- [ ] **Request metrics** accurate (open, overdue, due today)
- [ ] **Average TTR** calculation correct
- [ ] **Contract expiry** alerts working
- [ ] **PM counters** showing correct numbers
- [ ] **Unpaid invoices** KPI accurate
- [ ] **Real-time updates** refreshing KPIs

### Navigation & Deep Links
- [ ] **KPI card clicks** navigate correctly
- [ ] **Deep links** from notifications working
- [ ] **Back navigation** consistent
- [ ] **Drawer/menu** navigation working
- [ ] **Tab navigation** (if implemented)

---

## 🔄 Real-time Features

### Real-time Updates
- [ ] **Request status changes** update immediately
- [ ] **New requests** appear in lists
- [ ] **Assignment changes** reflect immediately
- [ ] **PM visit updates** real-time
- [ ] **Connection status** indicator working
- [ ] **Reconnection** after network issues

### Notifications
- [ ] **Critical status** notifications (on-site)
- [ ] **SLA breach** alerts showing
- [ ] **SLA warning** (≤15min) notifications
- [ ] **New critical request** notifications
- [ ] **Assignee change** notifications
- [ ] **PM completion** notifications
- [ ] **Notification actions** (View button) working

---

## 🎨 User Experience & Accessibility

### Loading States
- [ ] **Skeleton loading** for initial loads
- [ ] **Progressive loading** for images
- [ ] **Loading indicators** for actions
- [ ] **Pull-to-refresh** visual feedback
- [ ] **Infinite scroll** loading working
- [ ] **Network error** handling

### Empty States
- [ ] **No requests** empty state helpful
- [ ] **No search results** with clear action
- [ ] **No filtered results** with clear filters
- [ ] **Network errors** with retry option
- [ ] **Server errors** with helpful message
- [ ] **Unauthorized** access handled

### Accessibility
- [ ] **Touch targets** minimum 44pt
- [ ] **Screen reader** labels present
- [ ] **Color contrast** meets 4.5:1 ratio
- [ ] **Focus indicators** visible
- [ ] **Semantic markup** correct
- [ ] **Text scaling** support

### Visual Design
- [ ] **Material 3** design system consistent
- [ ] **Color theming** working correctly
- [ ] **Typography** hierarchy clear
- [ ] **Spacing** consistent (8pt grid)
- [ ] **Icons** appropriate and consistent
- [ ] **Brand elements** correctly applied

---

## 📱 Mobile Specific

### Platform Features
- [ ] **Camera access** for photo capture
- [ ] **File picker** for attachments
- [ ] **Network connectivity** detection
- [ ] **Background/foreground** state handling
- [ ] **App permissions** requested properly
- [ ] **Device orientation** handling

### Performance
- [ ] **App startup** time acceptable (<3s)
- [ ] **List scrolling** smooth (60fps)
- [ ] **Image loading** optimized
- [ ] **Memory usage** reasonable
- [ ] **Battery usage** acceptable
- [ ] **Offline handling** graceful

---

## 🔒 Security Testing

### Input Validation
- [ ] **XSS prevention** working
- [ ] **SQL injection** protection
- [ ] **File upload** validation
- [ ] **Email format** validation
- [ ] **Phone number** format validation
- [ ] **URL validation** working

### Data Protection
- [ ] **Tenant isolation** enforced everywhere
- [ ] **Cross-tenant** access blocked
- [ ] **Storage paths** validated
- [ ] **Session management** secure
- [ ] **API authentication** working
- [ ] **Error messages** don't leak sensitive data

### Privacy
- [ ] **Analytics** doesn't collect PII
- [ ] **Error reporting** sanitizes data
- [ ] **Debug logs** mask sensitive values
- [ ] **Configuration** hides secrets
- [ ] **User data** handled according to policy

---

## 🧪 Error Handling & Recovery

### Network Errors
- [ ] **Connection timeout** handled gracefully
- [ ] **Server errors** (5xx) show helpful messages
- [ ] **Rate limiting** handled appropriately
- [ ] **Retry mechanisms** working
- [ ] **Offline mode** handling (if implemented)

### App Errors
- [ ] **Unhandled exceptions** captured
- [ ] **Error boundaries** prevent crashes
- [ ] **Recovery options** available
- [ ] **Error reporting** functioning
- [ ] **Debug information** available in dev mode

### Data Validation
- [ ] **Form validation** clear and helpful
- [ ] **API validation** errors displayed
- [ ] **File upload** errors handled
- [ ] **Image processing** errors handled
- [ ] **Payment errors** handled gracefully

---

## 📈 Performance Testing

### Load Testing
- [ ] **Large request lists** (1000+ items)
- [ ] **Multiple file uploads** simultaneously
- [ ] **Concurrent user operations**
- [ ] **Database query performance**
- [ ] **Real-time subscription** scalability

### Memory Testing
- [ ] **Memory leaks** in list scrolling
- [ ] **Image caching** working efficiently
- [ ] **Provider disposal** cleanup
- [ ] **Long-running app** stability
- [ ] **Background task** management

---

## 🔧 Integration Testing

### Supabase Integration
- [ ] **Authentication** flow complete
- [ ] **Database operations** working
- [ ] **Storage operations** working
- [ ] **Real-time subscriptions** working
- [ ] **RLS policies** enforced
- [ ] **Edge functions** (if used) working

### Third-party Integrations
- [ ] **PhonePe payment** flow working
- [ ] **File picker** integration
- [ ] **Camera** integration
- [ ] **URL launcher** working
- [ ] **Analytics** integration (if configured)

---

## 📋 Final Checks

### Code Quality
- [ ] **Code review** completed
- [ ] **Test coverage** adequate (>80%)
- [ ] **Documentation** up to date
- [ ] **Changelog** updated
- [ ] **Version numbers** incremented
- [ ] **Build artifacts** generated

### Deployment
- [ ] **Production environment** configured
- [ ] **Database backups** configured
- [ ] **Monitoring** setup
- [ ] **Logging** configured
- [ ] **Error tracking** enabled
- [ ] **Performance monitoring** enabled

### Post-Deployment
- [ ] **Health checks** passing
- [ ] **Key user flows** tested in production
- [ ] **Performance metrics** baseline established
- [ ] **Error rates** within acceptable limits
- [ ] **User feedback** channels ready

---

## ✅ Sign-off

### Development Team
- [ ] **Feature complete** according to requirements
- [ ] **Technical debt** addressed or documented
- [ ] **Performance targets** met
- [ ] **Security requirements** satisfied

### QA Team
- [ ] **All test cases** passed
- [ ] **Regression testing** completed
- [ ] **Accessibility testing** passed
- [ ] **Performance testing** satisfactory

### Product Team
- [ ] **User acceptance** testing completed
- [ ] **Business requirements** satisfied
- [ ] **User experience** acceptable
- [ ] **Documentation** complete

---

**Testing Completed By:** ________________  
**Date:** ________________  
**Release Approved:** ☐ Yes ☐ No  
**Notes:** ________________________________

---

*This checklist ensures comprehensive testing of all MaintPulse features before production release. Each item should be verified and checked off before deployment.*