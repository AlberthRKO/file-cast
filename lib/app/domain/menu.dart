import 'package:flutter/material.dart';
import 'package:file_cast/app/presentation/routes/routes.dart';

class Menu {
  //default constructor
  Menu(
    this.level,
    this.icon,
    this.title,
    this.children,
    this.route,
    this.arguments,
  );

  //one method for  Json data
  Menu.fromJson(Map<String, dynamic> json) {
    //level
    if (json['level'] != null) {
      level = json['level'] as int;
    }
    //icon
    if (json['icon'] != null) {
      icon = json['icon'] as IconData;
    }
    if (json['route'] != null) {
      route = json['route'] as String;
    }
    if (json['arguments'] != null) {
      arguments = json['arguments'] as int;
    }
    //title
    title = json['title'] as String;
    //children
    if (json['children'] != null) {
      children.clear();
      //for each entry from json children add to the Node children
      json['children'].forEach((v) {
        children.add(Menu.fromJson(v as Map<String, dynamic>));
      });
    }
  }
  int level = 0;
  IconData icon = Icons.drive_file_rename_outline;
  String title = '';
  String route = Routes.home;
  int arguments = 50;
  List<Menu> children = [];
}
