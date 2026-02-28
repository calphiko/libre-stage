
def check_admin(current: dict) -> bool:
    if current["user_group"].upper() == "ADMIN":
        return True
    return False

def check_editor(current: dict) -> bool:
    if current["user_group"].upper() in ["ADMIN", "EDITOR"]:
        return True
    return False
