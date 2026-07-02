import 'package:flutter/material.dart';

class BottomBarState with ChangeNotifier {
  bool _showBottomBar = true;
  bool _showSidebar = false;

  bool get showBottomBar => _showBottomBar;
  bool get showSidebar => _showSidebar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }

  set showSidebar(bool value) {
    _showSidebar = value;
    notifyListeners();
  }
}

class ScreensState with ChangeNotifier {
  final _pageController = PageController();
  int _page = 0;

  // Gettes y settes de las variables privadas
  int get page => _page;
  PageController get pageController => _pageController;

  // si el valor cambia de 0 se redirecciona a la otra pagina con una animacion
  set page(int page) {
    _page = page;
    if (_page >= 0) {
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
      );
    }
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }
}

class BottomBarStateTabs with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class ScreensStateTabs with ChangeNotifier {
  final _pageController = PageController();
  int _page = 0;

  // Gettes y settes de las variables privadas
  int get page => _page;
  PageController get pageController => _pageController;

  // si el valor cambia de 0 se redirecciona a la otra pagina con una animacion
  set page(int page) {
    _page = page;
    if (_page >= 0) {
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
      );
    }
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }
}

class BottomBarStatePermisos with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class ScreensStatePermisos with ChangeNotifier {
  late final PageController _pageController;
  int _page;

  ScreensStatePermisos({int initialPage = 0}) : _page = initialPage {
    _pageController = PageController(initialPage: initialPage);
  }

  int get page => _page;
  PageController get pageController => _pageController;

  set page(int page) {
    if (_page == page) return;

    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _page,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class BottomBarStateActivos with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

/*class ScreensStateActivos with ChangeNotifier {
  final _pageController = PageController();
  int _page = 0;

  // Gettes y settes de las variables privadas
  int get page => _page;
  PageController get pageController => _pageController;

  // si el valor cambia de 0 se redirecciona a la otra pagina con una animacion
  set page(int page) {
    _page = page;
    if (_page >= 0) {
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
      );
    }
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }
}*/
class ScreensStateActivos with ChangeNotifier {
  late final PageController _pageController;
  int _page;

  ScreensStateActivos({int initialPage = 0}) : _page = initialPage {
    _pageController = PageController(initialPage: initialPage);
  }

  int get page => _page;
  PageController get pageController => _pageController;

  set page(int page) {
    if (_page == page) return;

    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _page,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class BottomBarStateAlmacenes with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class ScreensStateAlmacenes with ChangeNotifier {
  late final PageController _pageController;
  int _page;

  ScreensStateAlmacenes({int initialPage = 0}) : _page = initialPage {
    _pageController = PageController(initialPage: initialPage);
  }

  int get page => _page;
  PageController get pageController => _pageController;

  set page(int page) {
    if (_page == page) return;

    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _page,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

//seccion de home de ciudadania

class BottomBarStateHomeCiudadania with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class ScreensStateHomeCiudadania with ChangeNotifier {
  final _pageController = PageController();
  int _page = 0;

  // Gettes y settes de las variables privadas
  int get page => _page;
  PageController get pageController => _pageController;

  // si el valor cambia de 0 se redirecciona a la otra pagina con una animacion
  set page(int page) {
    _page = page;
    if (_page >= 0) {
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
      );
    }
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }
}

class BottomBarStateOptionsActividad with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class BottomBarStateFirmasPresentaciones with ChangeNotifier {
  bool _showBottomBar = true;

  bool get showBottomBar => _showBottomBar;

  set showBottomBar(bool hideMenu) {
    _showBottomBar = hideMenu;
    notifyListeners();
  }
}

class ScreensStateFirmasPresentaciones with ChangeNotifier {
  late final PageController _pageController;
  int _page;

  ScreensStateFirmasPresentaciones({int initialPage = 0})
      : _page = initialPage {
    _pageController = PageController(initialPage: initialPage);
  }

  int get page => _page;
  PageController get pageController => _pageController;

  set page(int page) {
    if (_page == page) return;

    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _page,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
    notifyListeners();
  }

  void updatePageIndex(int index) {
    if (_page != index) {
      _page = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
