// REQ-ID: REQ-API-001
// QD4: Performance issues — bundle size + unfiltered DB queries
import _ from 'lodash';
import moment from 'moment';

export async function getAllUsers() {
    // QD4: Unfiltered DB query — SELECT *
    return db.query('SELECT * FROM users');
}
