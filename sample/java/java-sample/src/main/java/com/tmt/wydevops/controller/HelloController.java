package com.tmt.wydevops.controller;

import com.alibaba.fastjson2.JSONObject;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @Description TODO
 * @Author wuyi
 * @Date 2024/6/10 18:36
 * @Version 1.0
 **/
@RestController
@RequestMapping("${url-prefix}")
public class HelloController {

    @GetMapping("/hello")
    public JSONObject getAlertAudioData() {
        JSONObject json = new JSONObject();
        json.put("name", "wydevops");
        json.put("birthday", "2024-05-29");
        return json;
    }

}
