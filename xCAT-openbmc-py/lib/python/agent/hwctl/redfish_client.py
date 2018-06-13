#!/usr/bin/env python
###############################################################################
# IBM(c) 2018 EPL license http://www.eclipse.org/legal/epl-v10.html
###############################################################################
# -*- coding: utf-8 -*-
#

import os
import requests
import json
import time
from requests.auth import AuthBase

from common import utils, rest
from common.exceptions import SelfClientException, SelfServerException

import logging
logger = logging.getLogger('xcatagent')

HTTP_PROTOCOL = "https://"
PROJECT_URL = "/redfish/v1"

CHASSIS_URL = PROJECT_URL + "/Chassis"
MANAGER_URL = PROJECT_URL + "/Managers"
SYSTEMS_URL = PROJECT_URL + "/Systems"
SESSION_URL = PROJECT_URL + "/SessionService/Sessions"

BMC_RESET_TYPE = "ForceRestart"

POWER_RESET_TYPE = {
    'boot'    : 'ForceRestart',
    'off'     : 'ForceOff',
    'on'      : 'ForceOn',
    'softoff' : 'GracefulShutdown',
    'reset'   : 'GracefulRestart'
}

BOOTSOURCE_SET_STATE = {
    "cd"    : "Cd",
    "def"   : "None",
    "floppy": "Floppy",
    "hd"    : 'Hdd',
    "net"   : "Pxe",
    "setup" : "BiosSetup",
}

BOOTSOURCE_GET_STATE = {
    "BiosSetup": "BIOS Setup",
    "Floppy"   : "Floppy",
    "Cd"       : "CD/DVD",
    "Hdd"      : "Hard Disk",
    "None"     : "BIOS default",
    "Pxe"      : "Network",
}

class RedfishRest(object):

    headers = {'Content-Type': 'application/json'}

    def __init__(self, name, **kwargs):

        self.name = name
        self.username = None
        self.password = None

        if 'nodeinfo' in kwargs:
            for key, value in kwargs['nodeinfo'].items():
                setattr(self, key, value)
        if not hasattr(self, 'bmcip'):
            self.bmcip = self.name

        self.verbose = kwargs.get('debugmode')
        self.messager = kwargs.get('messager')

        self.session = rest.RestSession()
        self.auth = None
        self.root_url = HTTP_PROTOCOL + self.bmcip

    def _print_record_log (self, msg, cmd, error_flag=False):

        if self.verbose or error_flag:
            localtime = time.asctime( time.localtime(time.time()) )
            log = self.name + ': [redfish_debug] ' + cmd + ' ' + msg
            if self.verbose:
                self.messager.info(localtime + ' ' + log)
            logger.debug(log)

    def _print_error_log (self, msg, cmd):

        self._print_record_log(msg, cmd, True)

    def _log_request (self, method, url, headers, data=None, files=None, file_path=None, cmd=''):

        header_str = ' '.join([ "%s: %s" % (k, v) for k,v in headers.items() ])
        msg = 'curl -k -X %s -H \"%s\" ' % (method, header_str)

        if cmd != 'login':
            msg += '-H \"X-Auth-Token: xxxxxx\" '

        if data:
            if cmd == 'login':
                data = data.replace('"Password": "%s"' % self.password, '"Password": "xxxxxx"')
                data += ' -v'
            msg += '%s -d \'%s\'' % (url, data)
        else:
            msg += url

        self._print_record_log(msg, cmd)
        return msg

    def request (self, method, resource, headers=None, payload=None, timeout=30, cmd=''):

        httpheaders = headers or RedfishRest.headers
        url = resource
        if not url.startswith(HTTP_PROTOCOL):
            url = self.root_url + resource

        data = None
        if payload:
            data=json.dumps(payload)

        self._log_request(method, url, httpheaders, data=data, cmd=cmd)
        try:
            response = self.session.request(method, url, httpheaders, authType=self.auth, data=data, timeout=timeout)
            return self.handle_response(response, cmd=cmd)
        except SelfServerException as e:
            if cmd == 'login':
                e.message = "Login to BMC failed: Can't connect to {0} {1}.".format(e.host_and_port, e.detail_msg)
            else:
                e.message = 'BMC did not respond. ' \
                            'Validate BMC configuration and retry the command.'
            self._print_error_log(e.message, cmd)
            raise
        except ValueError:
            error = 'Received wrong format response: %s' % response
            self._print_error_log(error, cmd)
            raise SelfServerException(error)

    def handle_response (self, resp, cmd=''):

        data = resp.json()
        code = resp.status_code

        if code != requests.codes.ok and code != requests.codes.created:

            description = ''.join(data['error']['@Message.ExtendedInfo'][0]['Message'])
            error = '[%d] %s' % (code, description)
            self._print_error_log(error, cmd)
            raise SelfClientException(error, code)

        if cmd == 'login' and not 'X-Auth-Token' in resp.headers:
            raise SelfServerException('Login Failed: Did not get Session Token from response')

        if not self.auth:
            self.auth = RedfishAuth(resp.headers['X-Auth-Token'])

        self._print_record_log('%s %s' % (code, data['Name']), cmd)
        return data

    def login(self):

        payload = { "UserName": self.username, "Password": self.password }
        self.request('POST', SESSION_URL, payload=payload, timeout=20, cmd='login') 

    def _get_members(self, url):

        data = self.request('GET', url, cmd='get_members')
        try:
            return data['Members']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

    def get_bmc_state(self):

        members = self._get_members(MANAGER_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_bmc_state')
        try:
            return data['PowerState']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

    def get_power_state(self):

        members = self._get_members(CHASSIS_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_power_state')
        try:
            return data['PowerState']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

    def _get_bmc_actions(self):

        members = self._get_members(MANAGER_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_bmc_actions')
        try:
            actions = data['Actions']['#Manager.Reset']['ResetType@Redfish.AllowableValues']
            target_url = data['Actions']['#Manager.Reset']['target']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

        return (target_url, actions)

    def reboot_bmc(self, optype='warm'):

        target_url, actions = self._get_bmc_actions()
        if BMC_RESET_TYPE not in actions:
            raise SelfClientException('Unsupport option: %s' % BMC_RESET_TYPE)

        data = { "ResetType": BMC_RESET_TYPE }
        payload = json.dumps(data)
        return self.request('POST', target_url, payload=payload, cmd='set_bmc_state')

    def _get_power_actions(self):

        members = self._get_members(CHASSIS_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_power_actions')
        try:
            actions = data['Actions']['#ComputerSystem.Reset']['ResetType@Redfish.AllowableValues']
            target_url = data['Actions']['#ComputerSystem.Reset']['target']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

        return (target_url, actions)

    def set_power_state(self, state):

        target_url, actions = self._get_power_actions()
        if POWER_RESET_TYPE[state] not in actions:
            raise SelfClientException('Unsupport option: %s' % state)

        data = { "ResetType": state }
        payload = json.dumps(data)
        return self.request('POST', target_url, payload=payload, cmd='set_power_state')

    def get_boot_state(self):

        members = self._get_members(SYSTEMS_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_boot_state')
        try:
            boot_enable = data['Boot']['BootSourceOverrideEnabled']
            if boot_enable == 'None':
                return 'boot override inactive'
            bootsource = data['Boot']['BootSourceOverrideTarget']
            return BOOTSOURCE_GET_STATE.get(bootsource, bootsource)
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

    def _get_boot_actions(self):

        members = self._get_members(SYSTEMS_URL)
        target_url = members[0]['@odata.id']
        data = self.request('GET', target_url, cmd='get_boot_actions')
        try:
            actions = data['Boot']['BootSourceOverrideTarget@Redfish.AllowableValues']
        except KeyError as e:
            raise SelfServerException('Get KeyError %s' % e.message)

        return (target_url, actions) 

    def set_boot_state(self, persistant, state):

        target_url, actions = self._get_boot_actions()
        target_data = BOOTSOURCE_SET_STATE[state]
        if target_data not in actions:
            raise SelfClientException('Unsupport option: %s' % state)

        boot_enable = 'Once'
        if persistant:
            boot_enable = 'Continuous' 
        data = {'Boot': {'BootSourceOverrideEnabled': boot_enable, "BootSourceOverrideTarget": target_data} }
        json.dumps(data)
        return self.request('PATCH', target_url, payload=payload, cmd='set_boot_state')

class RedfishAuth(AuthBase):

    def __init__(self,authToken):

        self.authToken=authToken

    def __call__(self, auth):
        auth.headers['X-Auth-Token']=self.authToken
        return(auth)