class RemarkedAPIError(Exception):
    """
    Ошибка ответа Remarked API. `code`/`message` — поля из тела ответа
    (см. схемы Error400/Error401/Error429 в спеке Remarked), `status_code` —
    HTTP-статус ответа.
    """

    def __init__(self, code=None, message=None, status_code=None):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(f'Remarked API error {code}: {message}')
