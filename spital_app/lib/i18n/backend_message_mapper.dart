String backendMessageKey(dynamic rawMessage) {
  final message = (rawMessage ?? '').toString().trim();
  if (message.isEmpty) return 'error';

  const map = <String, String>{
    // Existing backend i18n keys (pass-through).
    'error_invalid_credentials': 'error_invalid_credentials',
    'error_account_disabled': 'error_account_disabled',
    'error_email_not_verified': 'error_email_not_verified',
    'error_invalid_or_expired_code': 'error_invalid_or_expired_code',
    'verification_code_resent': 'verification_code_resent',
    'email_verified_success': 'email_verified_success',
    'already_verified': 'already_verified',
    'register_verify_email': 'register_verify_email',
    'logout_success': 'logout_success',

    // Plain backend messages mapped to localization keys.
    'Neautentificat': 'backend_unauthenticated',
    'Acces neautorizat': 'backend_unauthorized',
    'Acces interzis': 'backend_access_denied',
    'Acces interzis. Rol insuficient.': 'backend_access_denied_role',
    'Contul este dezactivat': 'error_account_disabled',
    'Doar pacienții pot genera coduri de acces':
        'backend_only_patients_generate_code',
    'Doar însoțitorii pot folosi coduri de acces':
        'backend_only_companions_redeem_code',
    'Cod invalid sau expirat. Cere pacientului un cod nou.':
        'backend_invalid_or_expired_code',
    'Pacientul asociat codului nu mai există':
        'backend_code_patient_missing',
    'Asociere reușită! Poți acum vizualiza documentele pacientului.':
        'backend_association_success',
    'Doar pacienții pot trimite invitații':
        'backend_only_patients_send_invites',
    'Doar însoțitorii pot accepta invitații':
        'backend_only_companions_accept_invites',
    'Link de invitație invalid sau expirat.':
        'backend_invalid_or_expired_invite',
    'Pacientul asociat invitației nu mai există':
        'backend_invite_patient_missing',
    'Invitație acceptată! Poți acum vizualiza documentele pacientului.':
        'backend_invite_accepted_success',
    'Însoțitor deconectat': 'backend_companion_unlinked',
    'Relație cu pacientul eliminată': 'backend_patient_link_removed',
    'ID-ul specificat nu apartine unui pacient':
        'backend_selected_id_not_patient',
    'patient_id nu apartine unui pacient': 'backend_selected_id_not_patient',
    'Document sters': 'backend_document_deleted',
    'Spitalul a fost sters': 'backend_hospital_deleted',
    'Nu poti sterge propriul cont din aceasta interfata':
        'backend_cannot_delete_self',
    'Utilizatorul a fost sters': 'backend_user_deleted',
    'Utilizatorul selectat nu este pacient':
        'backend_selected_user_not_patient',
    'Utilizatorul selectat nu este insotitor':
        'backend_selected_user_not_companion',
    'Insotitor legat cu succes': 'backend_companion_linked',
    'Insotitor dezlegat': 'backend_companion_unlinked',
    'API key invalid': 'backend_invalid_api_key',
    'CNP-ul pacientului nu a putut fi identificat. Introduceți cnp_pacient explicit în payload sau includeți CNP-ul în numele fișierului / textul PDF.':
        'backend_cnp_not_identified',
    'CNP-ul pacientului nu a putut fi identificat.':
        'backend_cnp_not_identified',
    'Document ingerat cu succes': 'backend_document_ingested',
  };

  return map[message] ?? message;
}
